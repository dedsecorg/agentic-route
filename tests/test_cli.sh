#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 dedsecorg
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/bin/agentic-route"
CONF="$(mktemp "$ROOT/.test-routes.XXXXXX")"
trap 'rm -f "$CONF"' EXIT
printf '%s\n' '{"version":1,"rules":[],"forbidden_rules":[],"pinned_routes":[]}' > "$CONF"
export AGENTIC_ROUTE_CONF="$CONF"
bash -n "$BIN" "$ROOT/lib/core.sh" "$ROOT/install.sh"
"$BIN" status >/dev/null
"$BIN" check
printf '%s\n' '{"version":1,"rules":[{"prio":99,"selector":"from 192.0.2.10","action":"lookup main"}],"forbidden_rules":[],"pinned_routes":[]}' > "$CONF"
if "$BIN" check >/dev/null 2>&1; then
    echo "check failed to report drift" >&2
    exit 1
fi
bash -n "$ROOT/bin/agentic-route-reconcile" "$ROOT/bin/agentic-route-daemon" "$ROOT/bin/net-safe"

# MCP contract: read-only, exactly four tools, JSON-RPC errors for bad input
MCP_OUT=$(printf '%s\n' \
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
    '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
    '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
    '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"route_check","arguments":{}}}' \
    '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"route_trace","arguments":{}}}' \
    '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"route_enforce","arguments":{}}}' \
    '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"route_trace","arguments":{"target":"256.1.1.1"}}}' \
    | "$BIN" mcp 2>/dev/null)
[ "$(printf '%s\n' "$MCP_OUT" | wc -l)" -eq 6 ] || { echo "mcp: expected 6 responses (notification must be ignored)" >&2; exit 1; }
mcp_has() { printf '%s\n' "$MCP_OUT" | jq -se "any($1)" >/dev/null || { echo "mcp: assertion failed: $1" >&2; exit 1; }; }
mcp_has '.id==1 and (.result.protocolVersion|type)=="string"'
[ "$(printf '%s\n' "$MCP_OUT" | jq -r 'select(.id==2) | .result.tools[].name' | sort | tr '\n' ' ')" = "route_check route_diff route_status route_trace " ] \
    || { echo "mcp: tools/list must expose exactly the four read-only tools" >&2; exit 1; }
mcp_has '.id==3 and (.result.content[0].text|test("drift detected"))'
mcp_has '.id==4 and .error.code==-32602'
mcp_has '.id==5 and .error.code==-32601'
mcp_has '.id==6 and .result.isError==true'

# --- Regression: forbidden-rule .match is a literal substring, not a regex ---
# Fake `ip`/`sysctl`/iptables so the reconciler and net-safe run unprivileged.
SHIM="$(mktemp -d "$ROOT/.test-shim.XXXXXX")"
trap 'rm -rf "$CONF" "$SHIM"' EXIT
cat > "$SHIM/ip" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"rule show"*)
    printf '0:\tfrom all lookup local\n'
    printf '100:\tfrom all lookup 205\n'
    printf '32764:\tnot from all fwmark 0xe1f1 lookup 205\n'
    printf '32766:\tfrom all lookup main\n'
    printf '32767:\tfrom all lookup default\n' ;;
  *"route show"*) printf 'default via 192.0.2.1 dev eth0\n' ;;
  *) printf '%s\n' "$*" >> "${SHIM_LOG:?}" ;;
esac
EOF
for t in sysctl iptables-save iptables-restore logger; do
    printf '#!/usr/bin/env bash\nprintf "%%s %%s\\n" "%s" "$*" >> "${SHIM_LOG:?}"\n' "$t" > "$SHIM/$t"
done
chmod +x "$SHIM"/*
export SHIM_LOG="$SHIM/calls.log"

# (a1) core.sh path (`diff`): `.match` "from all lookup 205" must flag prio 100
#      only, never the Nord egress rule `not from all fwmark 0xe1f1 lookup 205`.
printf '%s\n' '{"version":1,"rules":[],"forbidden_rules":[{"match":"from all lookup 205"}],"pinned_routes":[]}' > "$CONF"
DIFF_OUT=$(PATH="$SHIM:$PATH" "$BIN" diff 2>&1 || true)
printf '%s\n' "$DIFF_OUT" | grep -qE -- '^  - 100 +from all lookup 205$' \
    || { echo "diff: forbidden literal match must flag 'from all lookup 205'" >&2; exit 1; }
if printf '%s\n' "$DIFF_OUT" | grep -qF -- 'fwmark 0xe1f1'; then
    echo "diff: misclassified 'not from all fwmark 0xe1f1 lookup 205' as forbidden" >&2; exit 1
fi

# (a2) reconciler jq path. `.match` is a literal substring: "from all lookup 205"
#      must drop prio 100 from the effective spec but keep the Nord rule
#      `not from all fwmark 0xe1f1 lookup 205`; a regex-looking `20[0-9]` must
#      match nothing. Effective rules must be {prio,selector,action} for core.sh.
INTENT="$(mktemp "$ROOT/.test-intent.XXXXXX")"
STATE="$(mktemp -d "$ROOT/.test-state.XXXXXX")"
trap 'rm -rf "$CONF" "$SHIM" "$INTENT" "$STATE"' EXIT
printf '%s\n' '{"forbidden_rules":[{"match":"from all lookup 205"},{"match":"fwmark 0xe1f1 lookup 20[0-9]"}],"pinned_routes":[],"custom_rules":[]}' > "$INTENT"
EFF=$(PATH="$SHIM:$PATH" AGENTIC_ROUTE_LIB="$ROOT/lib/core.sh" AGENTIC_ROUTE_INTENT="$INTENT" AGENTIC_ROUTE_STATE_DIR="$STATE" bash -c '
    source <(sed "/^main \"\$@\"$/d" "$0")
    spec=$(build_effective_spec "$INTENT_FILE" "$(discover_rules)" "$(discover_routes)")
    cat "$spec"' "$ROOT/bin/agentic-route-reconcile")
[ "$(printf '%s' "$EFF" | jq -r '.rules[] | select(.prio==32764) | "\(.selector) \(.action)"')" = "not from all fwmark 0xe1f1 lookup 205" ] \
    || { echo "reconcile: Nord rule 32764 missing/mangled in effective spec - '.match' treated as regex?" >&2; printf '%s\n' "$EFF" >&2; exit 1; }
[ "$(printf '%s' "$EFF" | jq -r '.rules[] | select(.prio==100)' | wc -c)" -eq 0 ] \
    || { echo "reconcile: forbidden rule 100 must not be in effective spec" >&2; exit 1; }

# (a3) full enforce run against the shims: exactly one `ip rule del priority 100`,
#      and no `ip rule add` (every discovered rule is already live).
: > "$SHIM_LOG"
rc=0
PATH="$SHIM:$PATH" AGENTIC_ROUTE_LIB="$ROOT/lib/core.sh" AGENTIC_ROUTE_INTENT="$INTENT" AGENTIC_ROUTE_STATE_DIR="$STATE" \
    "$ROOT/bin/agentic-route-reconcile" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 1 ] || { echo "reconcile: expected exit 1 (drift corrected), got $rc" >&2; exit 1; }
grep -qxF -- 'rule del priority 100' "$SHIM_LOG" || { echo "reconcile: must delete forbidden rule prio 100" >&2; exit 1; }
if grep -q -- 'rule del priority 32764' "$SHIM_LOG"; then
    echo "reconcile: deleted Nord rule 32764 - '.match' was treated as a regex" >&2; exit 1
fi
[ "$(grep -c -- 'rule del' "$SHIM_LOG")" -eq 1 ] || { echo "reconcile: exactly one rule deletion expected" >&2; cat "$SHIM_LOG" >&2; exit 1; }
if grep -q -- 'rule add' "$SHIM_LOG"; then
    echo "reconcile: re-added a live rule - forbidden '.match' misclassified it" >&2; cat "$SHIM_LOG" >&2; exit 1
fi

# --- Regression: net-safe restore replays captured rp_filter values verbatim ---
NS_STATE="$(mktemp -d "$ROOT/.test-netsafe.XXXXXX")"
trap 'rm -rf "$CONF" "$SHIM" "$INTENT" "$STATE" "$NS_STATE"' EXIT
touch "$NS_STATE/pending"
printf '32766:\tfrom all lookup main\n' > "$NS_STATE/ip_rule.snap"
printf 'table 205\ndefault via 192.0.2.1 dev eth0\n' > "$NS_STATE/ip_route.snap"
printf '1\n0\n' > "$NS_STATE/sysctl.snap"
printf 'eth0\n' > "$NS_STATE/dev"; printf '192.0.2.1\n' > "$NS_STATE/gw"
: > "$SHIM_LOG"
PATH="$SHIM:$PATH" NETSAFE_STATE_DIR="$NS_STATE" "$ROOT/bin/net-safe" rollback >/dev/null 2>&1 \
    || { echo "net-safe rollback failed" >&2; exit 1; }
grep -qxF -- 'sysctl -w net.ipv4.conf.all.rp_filter=1' "$SHIM_LOG" \
    || { echo "net-safe: all.rp_filter must be restored to snapshot value 1" >&2; cat "$SHIM_LOG" >&2; exit 1; }
grep -qxF -- 'sysctl -w net.ipv4.conf.default.rp_filter=0' "$SHIM_LOG" \
    || { echo "net-safe: default.rp_filter must be restored to snapshot value 0" >&2; cat "$SHIM_LOG" >&2; exit 1; }
if grep -q -- 'rp_filter=2' "$SHIM_LOG"; then
    echo "net-safe: rp_filter hardcoded to 2 instead of snapshot" >&2; exit 1
fi

# REST handler emits CRLF HTTP headers
HTTP_OUT=$("$BIN" api-handler <<< $'GET /api/v1/nope HTTP/1.1\r')
[ "${HTTP_OUT%%$'\n'*}" = $'HTTP/1.1 404 Not Found\r' ] || { echo "api-handler: expected CRLF 404 status line" >&2; exit 1; }

echo "agentic-route tests passed"
