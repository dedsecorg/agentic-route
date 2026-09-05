# Intent File (`/etc/agentic-route/intent.json`)

The **single source of truth** for your routing intent. Edit this file; the daemon watches it via `inotifywait` and reconciles automatically.

## Schema

```json
{
  "version": 1,
  "comment": "User intent only. Daemon writes discovered state to /run/agentic-route/state.json.",
  "forbidden_rules": [
    { "prio": 31580, "match": "suppress_prefixlength 0", "reason": "Remove VPN capture rule at this priority" },
    { "match": "100.64.0.0/10 lookup main", "reason": "Never let VPN redirect mesh CIDR through main table" }
  ],
  "pinned_routes": [
    { "dst": "198.51.100.7/32", "via": "192.0.2.1", "dev": "eth0", "reason": "Keep VPN endpoint reachable outside tunnel" },
    { "dst": "default", "via": "192.0.2.1", "dev": "eth0", "reason": "Bare-metal fallback egress" }
  ],
  "custom_rules": [
    { "prio": 480, "selector": "from all to 100.64.0.0/10", "action": "lookup 52" },
    { "prio": 32765, "selector": "not from all fwmark 0xe1f1", "action": "lookup 205" }
  ]
}
```

## Sections

### `forbidden_rules` — Rules to Remove

Rules matching these patterns are **deleted** if present in the kernel.

| Field | Required | Description |
|-------|----------|-------------|
| `prio` | No | If set, only matches rules at this exact priority. Prevents catching lookalikes at different priorities. |
| `match` | Yes | Substring match against the rule's selector+action (e.g., `lookup 245447468`). |
| `reason` | No | Documentation only. |

**Priority gating example:**
```json
{ "prio": 31581, "match": "lookup 245447468" }
```
Only deletes priority 31581 with that match — won't touch priority 32765 even if it has similar `lookup`.

### `pinned_routes` — Routes to Enforce

Routes that **must exist**. Uses `ip route replace` (idempotent).

| Field | Required | Description |
|-------|----------|-------------|
| `dst` | Yes | Destination (e.g., `198.51.100.7/32`, `default`) |
| `via` | No | Next hop IP |
| `dev` | No | Output interface |
| `reason` | No | Documentation only. |

### `custom_rules` — Rules to Ensure

Rules to **add if missing**. Merged with discovered kernel rules.

| Field | Required | Description |
|-------|----------|-------------|
| `prio` | Yes | Rule priority (0-32767) |
| `selector` | Yes | `ip rule` selector (e.g., `from all to 100.64.0.0/10`) |
| `action` | Yes | `ip rule` action (e.g., `lookup 52`) |
| `reason` | No | Documentation only. |

## How It Works

1. **Discover** — Read live `ip rule show` / `ip route show`
2. **Filter** — Remove discovered rules matching `forbidden_rules`
3. **Merge** — Add `custom_rules` not already present
4. **Apply** — `ip rule add/del`, `ip route replace` for delta only
5. **Emit** — Write `/run/agentic-route/state.json` with observed state + timestamp

