#!/usr/bin/env bash
# agentic-route-lib.sh - the reconciler ENGINE. Pure, portable, dependency-free.
# STATE HANDLER, not source of truth: it only
# reads routes.json and reconciles reality back to it.

# Guarantees:
#   * Never `ip route flush` / `ip rule flush` (surgical adds/dels only).
#   * Every mutation is check-then-act (ip rule add is NOT idempotent).
#   * Only removes rules/routes explicitly declared forbidden/undefined by spec.

AR_JSON="${AR_JSON:-/etc/agentic-route/routes.json}"
AR_DIFF_MODE="${AR_DIFF_MODE:-check}"   # check|enforce : check = report only, enforce = mutate

ar_log()  { [ "${AR_QUIET:-0}" = 1 ] || echo "[agentic-route] $*" >&2; }
ar_die()  { echo "[agentic-route] FATAL: $*" >&2; exit 1; }

# --- rule fingerprinting -------------------------------------------------------
# Normalize an `ip rule show` line: keep PRIO for ordering, then selector+action
# as emitted canonically by iproute2 (v6.1). We match on that canonical text.
ar_rule_get() {
  # Prints `PRIO<TAB>SELECTOR_ACTION` per live IPv4 rule.
  ip -4 rule show 2>/dev/null | awk -F':\t' '{ gsub(/[ \t]+/," ",$2); print $1 "\t" $2 }'
}

# ar_spec_rule PRIO - emit the declared selector+action for spec rule at PRIO.
ar_spec_rule() {
  local prio="$1"
  jq -r --argjson p "$prio" '.rules[] | select(.prio==$p) | "\(.selector) \(.action)"' "$AR_JSON" 2>/dev/null
}

# --- rule reconciliation -------------------------------------------------------
ar_reconcile_rules() {
  local -a to_add=()
  local -a to_del=()
  local prio sa entry

  # 1. Spec'd rules missing from live state -> add
  while IFS='|' read -r prio sa; do
    [ -z "$prio" ] && continue
    if ! ar_rule_get | grep -qF "$(printf '%s\t%s' "$prio" "$sa")"; then
      to_add+=("$prio|$sa")
    fi
  done < <(jq -r '.rules[] | "\(.prio)|\(.selector) \(.action)"' "$AR_JSON" 2>/dev/null)

  # 2. Live rules matching a forbidden pattern -> delete
  #    Forbidden entries may carry an optional `prio`. When present, the rule is
  #    only deleted if BOTH prio and the match substring align, so we can target
  #    Proton's specific priorities without catching Nord's lookalike rules.
  #    Patterns contain spaces, so read them line-wise (NOT `for f in $(...)`
  #    which word-splits and makes "lookup"/"main" match everything).
  local -a forbidden=()
  while IFS= read -r _f; do
    [ -n "$_f" ] && forbidden+=("$_f")
  done < <(jq -r '.forbidden_rules[]? | "\(.prio // 0)|\(.match)"' "$AR_JSON" 2>/dev/null)

  while IFS=$'\t' read -r prio sa; do
    [ -z "$prio" ] && continue
    # Skip rules we already declared in `rules[]` - they are NOT forbidden.
    ar_spec_rule "$prio" | grep -qF -- "$sa" && continue
    local f fprio fmatch
    for f in "${forbidden[@]}"; do
      fprio="${f%%|*}"; fmatch="${f#*|}"
      # priority gate: if the forbidden entry pins a prio, require exact match
      if [ "$fprio" != "0" ] && [ "$fprio" != "$prio" ]; then
        continue
      fi
      if printf '%s' "$sa" | grep -qF -- "$fmatch"; then
        to_del+=("$prio|$sa")
        break
      fi
    done
  done < <(ar_rule_get)

  # 3. Apply (surgical: del forbidden, add missing)
  for entry in "${to_del[@]}"; do
    prio="${entry%%|*}"; sa="${entry#*|}"
    if [ "$AR_DIFF_MODE" = "enforce" ]; then
      ip rule del priority "$prio" 2>/dev/null && ar_log "del rule $prio: $sa"
    else
      ar_log "would-del rule $prio: $sa"
    fi
  done
  for entry in "${to_add[@]}"; do
    prio="${entry%%|*}"; sa="${entry#*|}"
    if [ "$AR_DIFF_MODE" = "enforce" ]; then
      # shellcheck disable=SC2086
      ip rule add priority "$prio" $sa 2>/dev/null && ar_log "add rule $prio: $sa" \
        || ar_log "SKIP add rule $prio (exists or invalid): $sa"
    else
      ar_log "would-add rule $prio: $sa"
    fi
  done

  printf '%d\n' $((${#to_add[@]} + ${#to_del[@]}))
}

# --- route reconciliation ------------------------------------------------------
ar_route_get() {
  # canonical `ip route show` lines for matching (space-normalized).
  ip -4 route show 2>/dev/null | awk '{ gsub(/[ \t]+/," ",$0); sub(/^ +/,"",$0); print }'
}

# Normalize a dst for matching: iproute2 strips /32 (host routes) and shows a
# bare address, but keeps /24 etc. We do the same so spec and live agree.
ar_dst_normalize() {
  local d="$1"
  case "$d" in
    */32) printf '%s' "${d%/32}" ;;
    *)    printf '%s' "$d" ;;
  esac
}

ar_reconcile_routes() {
  local total=0 dst via dev raw_dst
  # jq emits dst<TAB>via<TAB>dev per pinned route.
  while IFS=$'\t' read -r raw_dst via dev; do
    [ -z "$raw_dst" ] && continue
    dst="$(ar_dst_normalize "$raw_dst")"

    # Match a live `ip route show` line whose dst-prefix equals `dst`.
    # Ignore extra attributes (proto/src/metric/scope); require via/dev if set.
    local match=1 line
    while read -r line; do
      case "$line" in
        "$dst "*|"$dst") ;;   # line starts with the normalized dst as a full token
        *) continue ;;
      esac
      [ -n "$via" ] && ! printf '%s' "$line" | grep -qF -- "$via" && continue
      [ -n "$dev" ] && ! printf '%s' "$line" | grep -qF -- "$dev" && continue
      match=0; break
    done < <(ar_route_get)

    [ "$match" -eq 0 ] && continue

    total=$((total+1))
    if [ "$AR_DIFF_MODE" = "enforce" ]; then
      local -a args=()
      if [ "$raw_dst" = "default" ]; then args+=("default"); else args+=("$raw_dst"); fi
      [ -n "$via" ] && args+=("via" "$via")
      [ -n "$dev" ] && args+=("dev" "$dev")
      ip route replace "${args[@]}" 2>/dev/null && ar_log "replace route: ${args[*]}"
    else
      ar_log "would-replace route: $raw_dst via ${via:-?} dev ${dev:-?}"
    fi
  done < <(jq -r '.pinned_routes[]? | [.dst, (.via // ""), (.dev // "")] | @tsv' "$AR_JSON" 2>/dev/null)

  printf '%d' "$total"
}

ar_apply_once() {
  local rcount pcount
  rcount=$(ar_reconcile_rules)
  pcount=$(ar_reconcile_routes)
  # Emit total drift count to stdout (callers capture it), zero-pad defensively.
  printf '%d\n' $(( (rcount + 0) + (pcount + 0) ))
}
