---
layout: default
title: MCP Integration
---

# MCP Integration

Start the read-only MCP server:
```bash
agentic-route mcp
```

Tools exposed:
- `route_status` — desired vs live rules/routes plus drift count
- `route_check` — drift detection, no mutation
- `route_diff` — would-add / would-del / would-replace, no mutation
- `route_trace` — `ip route get <target> [from <src>]`

Mutation (`enforce`, `reconcile`, intent edits) is deliberately **not**
exposed over MCP: an agent that can read routing state but not change it
cannot lock the host out. Mutation goes through the CLI or the mTLS REST API.

Reads `AGENTIC_ROUTE_CONF` (default `/etc/agentic-route/routes.json`).
See [api-reference.md](api-reference.md) for the full contract.
