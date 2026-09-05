---
title: API Reference
description: MCP tools and REST API reference
---

# API Reference

## MCP Tools

Start MCP server:
```bash
agentic-route mcp
```

### route_status

Returns current routing state.

```json
{
  "desired_rules": [...],
  "live_rules": [...],
  "desired_routes": [...],
  "live_routes": [...],
  "drift": {...}
}
```

### route_reconcile

Triggers one-shot reconciliation.

```json
{
  "success": true,
  "changes": 3
}
```

### route_daemon_status

Returns daemon state.

```json
{
  "running": true,
  "pid": 1234,
  "watching": "/etc/agentic-route/routes.json"
}
```

### route_intent_get

Returns current intent configuration.

### route_intent_set

Updates intent configuration.

```json
{
  "forbidden_rules": [...],
  "pinned_routes": [...],
  "vpn_interface": "proton0"
}
```

## REST API (Future)

Planned REST API endpoints:
- `GET /api/v1/status` — Full routing status
- `POST /api/v1/reconcile` — Trigger reconciliation
- `GET /api/v1/intent` — Get intent
- `PUT /api/v1/intent` — Set intent

EOF 2>&1
