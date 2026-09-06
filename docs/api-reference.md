---
title: API Reference
description: MCP tools and REST API reference
---

# API Reference

agentic-route exposes two machine interfaces with deliberately different
capabilities:

| Interface | Transport | Auth | Can mutate kernel state? |
|-----------|-----------|------|--------------------------|
| MCP (`agentic-route mcp`) | stdio JSON-RPC | process-local (whoever can spawn it) | **No** — read-only |
| REST (`agentic-route api`) | HTTPS, TLS 1.3, mTLS | X.509 client cert signed by `AGENTIC_ROUTE_TLS_CA` | Yes (`/api/v1/enforce`) |

## MCP Tools (read-only)

Start MCP server:
```bash
agentic-route mcp
```

Supported methods: `initialize`, `ping`, `tools/list`, `tools/call`.
Notifications are ignored. Unknown tools return JSON-RPC `-32601`; missing
required arguments return `-32602`.

### route_status

`cmd_status` output: desired spec vs live IPv4 rules/routes plus drift count.
No arguments.

### route_check

Drift detection. Returns the text `in-sync: no drift` or `drift detected
(run 'agentic-route diff' for detail)`. Never mutates. No arguments.

### route_diff

Precise would-add / would-del / would-replace listing. Never mutates.
No arguments.

### route_trace

```json
{ "target": "1.1.1.1", "from": "10.2.0.2" }
```

Runs `ip route get <target> [from <from>]`. `target` is required.

There are intentionally no `route_enforce`, `route_reconcile` or
`route_intent_set` tools: an agent that can read routing state but not change
it cannot lock the host out. Mutation goes through the CLI or the
authenticated REST API below.

## REST API (mTLS)

```bash
agentic-route api      # listens on AGENTIC_ROUTE_API_PORT (8099)
```

socat terminates TLS 1.3 with `verify=1`; the handler is only spawned after
the client presents a certificate chaining to `AGENTIC_ROUTE_TLS_CA`. There is
no plaintext mode. See [PKI](pki.md).

```bash
curl --cacert /etc/agentic-route/certs/ca.crt \
     --cert agent.crt --key agent.key \
     https://127.0.0.1:8099/api/v1/status
```

| Endpoint | Effect | Response |
|----------|--------|----------|
| `GET /api/v1/status` | none | `{"status":"ok","text":"..."}` |
| `GET /api/v1/check` | none | `{"status":"ok","drift":<n>}` |
| `GET /api/v1/diff` | none | `{"status":"ok","text":"..."}` |
| `GET /api/v1/enforce` | **applies** the spec | `{"status":"ok","corrected":<n>}` |

Anything else returns `404`. The spec is `AGENTIC_ROUTE_CONF`
(`/etc/agentic-route/routes.json`).
