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

## agentic-route mcp

Start the stdio MCP JSON-RPC server for AI agent integration. It is
**read-only**: no tool mutates kernel state. Mutation (`enforce`,
`reconcile`) stays a CLI/operator action or goes through the mTLS REST API.

```bash
agentic-route mcp
```

Tools exposed:
- `route_status` — desired vs live rules/routes plus drift count
- `route_check` — drift detection, no mutation
- `route_diff` — would-add / would-del / would-replace, no mutation
- `route_trace` — `ip route get <target> [from <src>]`

Methods: `initialize`, `ping`, `tools/list`, `tools/call`. Reads
`AGENTIC_ROUTE_CONF` (default `/etc/agentic-route/routes.json`).

## agentic-route api

mTLS REST API on `AGENTIC_ROUTE_API_PORT` (default 8099). Requires socat with
OpenSSL and a client certificate signed by `AGENTIC_ROUTE_TLS_CA`; see
[PKI](pki.md) and [API Reference](api-reference.md).
