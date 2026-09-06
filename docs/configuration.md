---
title: Configuration
description: agentic-route configuration reference
---

# Configuration

agentic-route has two configuration files with two different schemas. Both
live in `/etc/agentic-route/` and both are hand-edited; the tool never writes
either.

| File | Read by | Schema | Purpose |
|------|---------|--------|---------|
| `routes.json` (`AGENTIC_ROUTE_CONF`) | `agentic-route enforce/check/status/diff/monitor/api/mcp` (`lib/core.sh`) | **spec**: `rules`, `forbidden_rules`, `pinned_routes` | Full declarative desired rule set, applied directly |
| `intent.json` (`AGENTIC_ROUTE_INTENT`) | `agentic-route-reconcile`, `agentic-route-daemon` | **intent**: `forbidden_rules`, `pinned_routes`, `custom_rules` | Constraints only; the reconciler discovers live kernel state and compiles intent + discovery into an effective spec at runtime |

Use `routes.json` when you want to own every rule and route yourself. Use
`intent.json` (with the daemon) when VPN clients own most of the routing
table and you only want to pin, forbid or add a few things on top of what
they do. You may run both — the daemon and the CLI agree on the shared
`forbidden_rules` / `pinned_routes` semantics.

Examples: `etc/routes.json.example`, `etc/intent.json.example`
(`install.sh` copies both into `/etc/agentic-route/` if absent).

## `routes.json` — spec

```json
{
  "version": 1,
  "rules": [
    { "prio": 1000, "selector": "from all fwmark 0x80000/0xff0000", "action": "lookup main" }
  ],
  "forbidden_rules": [
    { "prio": 31580, "match": "suppress_prefixlength 0", "reason": "..." },
    { "match": "100.64.0.0/10 lookup main", "reason": "..." }
  ],
  "pinned_routes": [
    { "dst": "default", "via": "192.0.2.1", "dev": "eth0", "reason": "..." }
  ]
}
```

## `intent.json` — intent

```json
{
  "version": 1,
  "forbidden_rules": [
    { "prio": 31580, "match": "suppress_prefixlength 0", "reason": "..." },
    { "match": "100.64.0.0/10 lookup main", "reason": "..." }
  ],
  "pinned_routes": [
    { "dst": "default", "via": "192.0.2.1", "dev": "eth0", "reason": "..." }
  ],
  "custom_rules": [
    { "prio": 32765, "selector": "not from all fwmark 0xe1f1", "action": "lookup 205" }
  ]
}
```

## Field reference

### `rules` / `custom_rules`

In `routes.json`, `rules` is the complete set of rules that must exist. In
`intent.json`, `custom_rules` are added on top of whatever the reconciler
discovers live.

| Field | Type | Description |
|-------|------|-------------|
| `prio` | int | Rule priority (1-32767) |
| `selector` | string | `ip rule` selector, e.g. `from all fwmark 0xe1f1` |
| `action` | string | `ip rule` action, e.g. `lookup 205` |

### `forbidden_rules`

Live rules matching an entry are deleted.

| Field | Type | Description |
|-------|------|-------------|
| `prio` | int | Optional. If set, only a live rule at exactly this priority can match |
| `match` | string | **Literal** substring (not a regex) searched for in the live rule's `selector action` text. CIDRs, `0x` fwmarks and table numbers are matched byte-for-byte |
| `reason` | string | Free text |

### `pinned_routes`

Routes that must exist in `main`; re-added if a VPN client removes them.

| Field | Type | Description |
|-------|------|-------------|
| `dst` | string | Destination CIDR or `default` |
| `via` | string | Next hop (optional) |
| `dev` | string | Output interface (optional) |
| `reason` | string | Free text |

## Environment variables

| Variable | Default | Used by |
|----------|---------|---------|
| `AGENTIC_ROUTE_CONF` | `/etc/agentic-route/routes.json` | CLI, `api`, `mcp` |
| `AGENTIC_ROUTE_INTENT` | `/etc/agentic-route/intent.json` | `agentic-route-reconcile` |
| `AGENTIC_ROUTE_API_PORT` | `8099` | `api` |
| `AGENTIC_ROUTE_TLS_CERT` | `/etc/agentic-route/certs/api.crt` | `api` (mTLS, see [PKI](pki.md)) |
| `AGENTIC_ROUTE_TLS_KEY` | `/etc/agentic-route/certs/api.key` | `api` |
| `AGENTIC_ROUTE_TLS_CA` | `/etc/agentic-route/certs/ca.crt` | `api` |
| `AR_QUIET` | `0` | all — suppress log lines |
