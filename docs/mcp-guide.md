---
layout: default
title: MCP Integration
---

# MCP Integration

Start read-write MCP server:
```bash
agentic-route mcp
```

Tools exposed:
- `route_status` — all rules, routes, drift
- `route_reconcile` — run one-shot reconciliation
- `route_daemon_status` — daemon state
- `route_intent_get` — current intent
- `route_intent_set` — update intent

EOF 2>&1
