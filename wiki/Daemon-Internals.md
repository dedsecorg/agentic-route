# Daemon Internals

## FIFO Multiplexing

```bash
#!/usr/bin/env bash
set -eo pipefail

RUN_DIR="/run/agentic-route"
FIFO="$RUN_DIR/events.fifo"
INTENT_DIR="/etc/agentic-route"
RECONCILE_BIN="/usr/local/bin/agentic-route-reconcile"

mkdir -p "$RUN_DIR" "$INTENT_DIR"
[[ -p "$FIFO" ]] || mkfifo "$FIFO"

# Cleanup on exit
trap 'exec 3>&-; kill $(jobs -p) 2>/dev/null; rm -f "$FIFO"' EXIT INT TERM

# Stream 1: Intent file changes (directory watch survives vim atomic rename)
inotifywait -m -q -e close_write,moved_to --format '%f' "$INTENT_DIR/" > "$FIFO" 2>/dev/null &

# Stream 2: Kernel routing changes (Netlink)
ip monitor rule route link 2>/dev/null > "$FIFO" &

# Hold FIFO open on FD 3 so it never receives EOF when writers restart
exec 3<> "$FIFO"

# Unified debounced loop reading strictly from FD 3
while read -r event <&3; do
  # Drain burst events (200ms window)
  while read -r -t 0.2 -u 3 _; do :; done
  
  case "$event" in
    intent.json|*.json)
      log "intent file changed: $event"
      ;;
    *)
      log "kernel routing event"
      ;;
  esac
  
  if "$RECONCILE_BIN"; then
    :  # clean, no drift
  else
    log "drift corrected"
  fi
done
```

## Key Design Decisions

### Why `exec 3<> "$FIFO"`?
Without it, when `inotifywait` or `ip monitor` restarts, the FIFO has no writers -> reader sees EOF -> daemon exits. Holding FD 3 open keeps the pipe alive regardless of writer lifecycle.

### Why Directory Watch (`/etc/agentic-route/`)?
`vim` and editors write to a temp file then `rename()` over the target. A file watch on `intent.json` tracks the old inode and misses the new file. Directory watch catches `moved_to` events on the directory itself.

### Why 200ms Debounce?
VPN reconnects, DHCP renewals, and link changes fire 20-50 Netlink events in <100ms. Without debouncing, the daemon would fork `ip`, `jq`, and shell subshells 50 times, pegging CPU and fighting interface state mid-transition.

### Why Single Consumer Loop?
Bash pipelines create subshells. Variables set in a piped `while read` loop are lost when the loop exits. The single loop in the main process maintains state.

## Signal Handling

```bash
trap 'exec 3>&-; kill $(jobs -p) 2>/dev/null; rm -f "$FIFO"' EXIT INT TERM
```

- `exec 3>&-` closes the held FD, allowing FIFO to drain
- `kill $(jobs -p)` reaps background `inotifywait` and `ip monitor`
- `rm -f "$FIFO"` cleans up the pipe file

