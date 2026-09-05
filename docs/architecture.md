---
layout: default
title: Architecture
---

# Architecture

agentic-route manages Linux kernel policy routing via Netlink:

```
Intent JSON (/etc/agentic-route/routes.json)
        |
        v
agentic-route-reconcile (one-shot)
        |
        v
agentic-route-daemon (event-driven, inotifywait)
        |
        v
Netlink (rtnetlink, fib rules, routes)
        |
        v
Kernel routing tables
```

## Components

| Component | Role |
|-----------|------|
| `routes.json` | Desired state: forbidden rules, pinned routes, VPN interface |
| `agentic-route-reconcile` | Discovers live state, computes delta, applies diffs |
| `agentic-route-daemon` | Watches intent file, debounced reconciliation (200ms) |
| `hermes-route-lib.sh` | Shared library (AR_ → HR_ prefix rename) |

EOF 2>&1
