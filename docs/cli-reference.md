---
title: CLI Reference
description: Complete command reference for agentic-route
---

# CLI Reference

## agentic-route status

Show current routing state including policy rules, routes, and drift.

```bash
agentic-route status
```

Output includes:
- Desired rules from intent file
- Live IPv4 rules from kernel
- Desired pinned routes
- Live IPv4 routes
- Drift detection results

## agentic-route reconcile

Run one-shot reconciliation to align kernel state with intent.

```bash
agentic-route reconcile
```

## agentic-route daemon

Run event-driven daemon that watches intent file for changes.

```bash
agentic-route daemon
```

Options:
- `--interval <ms>` — debounce interval (default: 200ms)
- `--state-dir <path>` — state directory (default: /run/agentic-route)

## agentic-route intent get

Show current intent configuration.

```bash
agentic-route intent get
```

## agentic-route intent set

Update intent file from stdin or file.

```bash
agentic-route intent set <file>
# or
cat intent.json | agentic-route intent set
```

## agentic-route mcp

Start stdio MCP JSON-RPC server for AI agent integration.

```bash
agentic-route mcp
```

Tools exposed:
- `route_status`
- `route_reconcile`
- `route_daemon_status`
- `route_intent_get`
- `route_intent_set`

EOF 2>&1
