---
layout: default
title: Architecture
---

# Architecture

agentic-route manages Linux kernel policy routing via Netlink:

```
Intent JSON (/etc/agentic-route/intent.json)
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
| `intent.json` | Intent: forbidden rules, pinned routes, custom rules (reconciler/daemon) |
| `routes.json` | Full spec: rules, forbidden rules, pinned routes (`agentic-route` CLI) |
| `agentic-route-reconcile` | Discovers live state, computes delta, applies diffs |
| `agentic-route-daemon` | Watches intent file, debounced reconciliation (200ms) |
| `hermes-route-lib.sh` | Shared library (AR_ → HR_ prefix rename) |

EOF 2>&1
