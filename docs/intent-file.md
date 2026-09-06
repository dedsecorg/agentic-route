---
layout: default
title: Intent File
---

# Intent File (`/etc/agentic-route/intent.json`)

Read by `agentic-route-reconcile` and `agentic-route-daemon` (override with
`AGENTIC_ROUTE_INTENT`). Not to be confused with `routes.json`, the full spec
read by the `agentic-route` CLI — see [Configuration](configuration.md) for
both schemas side by side.

```json
{
  "version": 1,
  "forbidden_rules": [
    { "prio": 31580, "match": "suppress_prefixlength 0", "reason": "ProtonVPN capture rule" },
    { "match": "100.64.0.0/10 lookup main", "reason": "Never route the mesh via main" }
  ],
  "pinned_routes": [
    { "dst": "default", "via": "192.0.2.1", "dev": "eth0", "reason": "Keep fallback egress" }
  ],
  "custom_rules": [
    { "prio": 32765, "selector": "not from all fwmark 0xe1f1", "action": "lookup 205" }
  ]
}
```

- `forbidden_rules[].match` is a **literal substring** of the live rule's
  `selector action` text, optionally scoped to `prio`. No regex.
- `pinned_routes` are re-added to `main` whenever a VPN client removes them.
- `custom_rules` are added on top of the rules the reconciler discovers.

Full field reference: [Configuration](configuration.md). Example:
`etc/intent.json.example`.
