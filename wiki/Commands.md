# Commands

## Overview

| Command | Description | Mutates Kernel |
|---------|-------------|----------------|
| `agentic-route status` | Show desired vs live rules/routes + drift | No |
| `agentic-route check` | Exit 0 if clean, 1 if drift | No |
| `agentic-route diff` | Precise read-only diff: +add, -del, ~replace | No |
| `agentic-route trace <target> [from <src>]` | Trace packet path via `ip route get` | No |
| `agentic-route enforce` | One-shot surgical reconciliation | Yes |
| `agentic-route reconcile` | **Idempotent one-shot** (discovers + intent + applies) | Yes |
| `agentic-route daemon` | **Event-driven daemon** (inotify + ip monitor + FIFO) | Yes |
| `agentic-route monitor` | Legacy: `ip monitor | while read` loop | Yes |
| `agentic-route mcp` | Read-only stdio MCP JSON-RPC server | No |
| `agentic-route api` | Local REST API server (port 8099) | No |

## Daemon vs Reconcile

| Aspect | `reconcile` | `daemon` |
|--------|-------------|----------|
| Trigger | Manual / cron / CI | Events (file change + Netlink) |
| Latency | Immediate | < 200ms after event |
| Use case | Deploy hooks, on-demand | Continuous production |
| Idempotence | Strict | Strict |
| Resource usage | Short-lived | ~1 MB RAM, ~0% CPU idle |

## Status Output

```bash
$ agentic-route status
agentic-route status
Spec: /etc/agentic-route/routes.json

--- Desired rules ---
  480: from all to 100.64.0.0/10 lookup 52
  32765: not from all fwmark 0xe1f1 lookup 205

--- Live IPv4 rules ---
  0: from all lookup local
  100: from 192.0.2.10 lookup wan
  480: from all to 100.64.0.0/10 lookup 52
  32765: not from all fwmark 0xe1f1 lookup 205
  32766: from all lookup main
  32767: from all lookup default

--- Desired pinned routes ---
  198.51.100.7/32 via 192.0.2.1 dev eth0
  default via 192.0.2.1 dev eth0

--- Live IPv4 routes ---
  default via 192.0.2.1 dev eth0
  198.51.100.7 via 192.0.2.1 dev eth0

--- Drift ---
agentic-route diff
Spec: /etc/agentic-route/routes.json

--- rules missing from live (would-add) ---
--- forbidden rules present (would-del) ---
--- pinned routes missing (would-replace) ---
(read-only: run 'agentic-route enforce' to apply)
```

## Diff Output

```bash
$ agentic-route diff
agentic-route diff
Spec: /etc/agentic-route/routes.json

--- rules missing from live (would-add) ---
  + 480  from all to 100.64.0.0/10 lookup 52

--- forbidden rules present (would-del) ---
  - 31581  from all lookup 245447468

--- pinned routes missing (would-replace) ---
  ~ 198.51.100.7/32 via 192.0.2.1 dev eth0
```

