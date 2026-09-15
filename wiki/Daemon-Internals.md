# Daemon Internals

## FIFO Multiplexing

The daemon uses a unified event loop fed by two FIFO streams:

```bash
#!/usr/bin/env bash
set -eo pipefail

RUN_DIR="/run/agentic-route"
FIFO="$RUN_DIR/events.fifo"
INTENT_FILE="${AGENTIC_ROUTE_INTENT:-/etc/agentic-route/intent.json}"
INTENT_DIR="$(dirname "$INTENT_FILE")"
INTENT_NAME="$(basename "$INTENT_FILE")"
RECONCILE_BIN="/usr/local/bin/agentic-route-reconcile"

# Configurable delay (seconds) before reconciling after the last event.
# Acts as a safeguard window for AI agents making routing changes.
RECONCILE_DELAY="${AGENTIC_ROUTE_RECONCILE_DELAY:-60}"

mkdir -p "$RUN_DIR" "$INTENT_DIR"
[[ -p "$FIFO" ]] || mkfifo "$FIFO"

cleanup() {
  [ -n "${reconcile_timer_pid:-}" ] && kill "$reconcile_timer_pid" 2>/dev/null || true
  exec 3>&- 3<&-
  kill $(jobs -p) 2>/dev/null || true
  rm -f "$FIFO"
}
trap cleanup EXIT INT TERM

ar_log() { echo "[agentic-route-daemon] $*" >&2; }

# Run reconciliation, handling exit codes consistently:
#   0 = no drift, all good
#   1 = drift corrected (normal)
#   2+ = error (logged but daemon stays alive)
reconcile() {
  "$RECONCILE_BIN" 2>&1
  local rc=$?
  if [ "$rc" -gt 1 ]; then
    ar_log "reconcile exited with error (exit $rc)"
  fi
  return 0
}

# Stream 1: Intent file changes (directory watch survives vim atomic rename)
inotifywait -m -q -e close_write,moved_to --format '%f' "$INTENT_DIR/" > "$FIFO" 2>/dev/null &

# Stream 2: Kernel routing changes (Netlink)
ip monitor rule route link 2>/dev/null > "$FIFO" &

# Hold FIFO open on FD 3 so it never receives EOF when writers restart
exec 3<> "$FIFO"

ar_log "daemon started, watching for routing events (reconcile delay: ${RECONCILE_DELAY}s)"

# Track whether the timer is currently pending
timer_pending=false
reconcile_timer_pid=""

cancel_timer() {
  if [ -n "${reconcile_timer_pid:-}" ]; then
    kill "$reconcile_timer_pid" 2>/dev/null || true
    wait "$reconcile_timer_pid" 2>/dev/null || true
    reconcile_timer_pid=""
  fi
  timer_pending=false
}

# Schedule reconciliation after RECONCILE_DELAY seconds.
# If a timer is already pending, it gets reset (cancels old, starts new).
schedule_reconcile() {
  cancel_timer
  if [ "$RECONCILE_DELAY" -eq 0 ]; then
    ar_log "running reconciliation (delay disabled)"
    reconcile
  else
    (
      sleep "$RECONCILE_DELAY"
      ar_log "delay timer elapsed, running reconciliation"
      reconcile
    ) &
    reconcile_timer_pid=$!
    timer_pending=true
  fi
}

# Unified debounced loop reading strictly from FD 3
while read -r event <&3; do
  # Drain burst events within a 200ms window
  while read -r -t 0.2 -u 3 _; do
    :
  done

  case "$event" in
    "$INTENT_NAME")
      ar_log "intent file changed: $event"
      ;;
    *)
      ar_log "kernel routing event detected"
      ;;
  esac

  # Schedule reconciliation with delay (acts as safeguard window)
  schedule_reconcile
done

cleanup
ar_log "daemon stopped"
```

## Key Design Decisions

### Why `exec 3<> "$FIFO"`?
Without it, when `inotifywait` or `ip monitor` restarts, the FIFO has no writers -> reader sees EOF -> daemon exits. Holding FD 3 open keeps the pipe alive regardless of writer lifecycle.

### Why Directory Watch (`$INTENT_DIR/`)?
`vim` and editors write to a temp file then `rename()` over the target. A file watch on `intent.json` tracks the old inode and misses the new file. Directory watch catches `moved_to` events on the directory itself.

### Why 60s Reconcile Delay?
AI agents (including this daemon's reconciler) may make transient routing changes during normal operation. A 60-second delay (configurable via `AGENTIC_ROUTE_RECONCILE_DELAY`) acts as a safeguard window: the daemon waits this many seconds after the last event before reconciling, allowing agents to complete their changes without the daemon racing to undo them. Set to 0 to disable.

### Why 200ms Debounce?
VPN reconnects, DHCP renewals, and link changes fire 20-50 Netlink events in <100ms. Without debouncing, the daemon would fork `ip`, `jq`, and shell subshells 50 times, pegging CPU and fighting interface state mid-transition.

### Why Single Consumer Loop?
Bash pipelines create subshells. Variables set in a piped `while read` loop are lost when the loop exits. The single loop in the main process maintains state.

### Why Consistent Exit Code Handling?
Reconcile returns 0 (no drift), 1 (drift corrected), or 2+ (error). Both invocation paths - the immediate path (delay=0) and the timer-based path - use the same `reconcile()` wrapper function. Exit codes 0 and 1 are silent (normal); exit 2+ logs an error but keeps the daemon alive instead of crashing under `set -e`.

## Signal Handling
```bash
trap cleanup EXIT INT TERM
```

- `reconcile_timer_pid` kill stops pending delayed reconciliation
- `exec 3>&-` closes the held FD, allowing FIFO to drain
- `kill $(jobs -p)` reaps background `inotifywait` and `ip monitor`
- `rm -f "$FIFO"` cleans up the pipe file
