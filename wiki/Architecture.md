# Architecture

## High-Level Flow

```
+---------------------+     inotifywait      +------------------+
|  /etc/agentic-route/|<---------------------|  intent.json     |
|  (directory watch)  |   (survives vim)     |  (user intent)   |
+----------+----------+                      +------------------+
           |                                      ^
           | events                               | edit
           v                                      |
+---------------------+     ip monitor           |
|   FIFO multiplexer  |<--------------------------+
|  (exec 3<> "$FIFO") |   kernel Netlink
+----------+----------+
           | 200ms debounce
           v
+---------------------+
|  reconcile binary   |
|  (idempotent)       |
+----------+----------+
           | surgical ip rule/route
           v
+---------------------+
|  Kernel routing     |
|  tables + rules     |
+---------------------+
```

## Components

### 1. Intent File (`/etc/agentic-route/intent.json`)
User-editable declaration of routing intent. See [[Intent-File]].

### 2. Reconciliation Engine (`/usr/local/lib/agentic-route/core.sh`)
Pure Bash library, zero dependencies. Functions:
- `ar_rule_get` — normalize live `ip rule show`
- `ar_spec_rule` — extract rule from spec by priority
- `ar_reconcile_rules` — add missing, delete forbidden
- `ar_reconcile_routes` — replace missing pinned routes
- `ar_apply_once` — single pass, returns drift count

### 3. Reconcile Binary (`/usr/local/bin/agentic-route-reconcile`)
Idempotent one-shot:
1. Discovers live kernel state
2. Builds effective spec from intent + discovered
3. Calls `ar_apply_once`
4. Updates `/run/agentic-route/state.json`

### 4. Daemon (`/usr/local/bin/agentic-route-daemon`)
Event-driven FIFO multiplexer:
- **Stream 1**: `inotifywait -m -q -e close_write,moved_to --format '%f' /etc/agentic-route/`
- **Stream 2**: `ip monitor rule route link`
- **FIFO**: `exec 3<> "$FIFO"` holds pipe open permanently
- **Loop**: `read -u 3` + `read -t 0.2 -u 3` (200ms debounce)
- **Action**: calls `agentic-route-reconcile`

### 5. State File (`/run/agentic-route/state.json`)
Daemon-written, read-only for humans:
```json
{
  "discovered_rules": [...],
  "discovered_routes": [...],
  "last_reconcile": "2026-09-04T14:29:22Z",
  "drift_corrected": 0
}
```

## Kubernetes Controller Pattern

```
Observed (kernel) + Intent (/etc/.../intent.json)
  -> Compute Delta
  -> Apply (surgical ip rule/route)
  -> Emit Status (/run/.../state.json)
```

## Hardened Against 5 Bash Daemon Bugs

| Bug | Fix |
|-----|-----|
| Subshell scope isolation | Single consumer loop in main process |
| Netlink echo loop | Idempotent reconcile + debounce |
| Burst storm (50 events/100ms) | `read -t 0.2` drains burst |
| inotify inode trap (`vim` rename) | Directory watch, not file watch |
| FIFO EOF death (writer restart) | `exec 3<> "$FIFO"` holds pipe open |

