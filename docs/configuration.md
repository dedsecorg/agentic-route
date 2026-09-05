---
title: Configuration
description: agentic-route configuration reference
---

# Configuration

## Intent File (/etc/agentic-route/routes.json)

```json
{
  "forbidden_rules": [
    {"priority": 31580, "table": "main", "description": "ProtonVPN split-tunnel daemon"},
    {"priority": 31581, "table": "main", "description": "ProtonVPN split-tunnel daemon"},
    {"priority": 32765, "table": "main", "description": "Tailscale hijack prevention"}
  ],
  "pinned_routes": [
    {"dst": "10.2.0.0/24", "dev": "proton0", "table": "main", "description": "ProtonVPN endpoint"},
    {"dst": "default", "dev": "eth0", "table": "main", "description": "Default via eth0"}
  ],
  "vpn_interface": "proton0"
}
```

## Forbidden Rules

Rules that the daemon will remove if present in kernel routing tables.

| Field | Type | Description |
|-------|------|-------------|
| priority | int | Rule priority (1-32767) |
| table | string | Routing table name |
| description | string | Human-readable description |

## Pinned Routes

Routes that the daemon ensures exist in kernel routing tables.

| Field | Type | Description |
|-------|------|-------------|
| dst | string | Destination CIDR or 'default' |
| dev | string | Network interface |
| table | string | Routing table name |
| description | string | Human-readable description |

## VPN Interface

The interface name for VPN traffic. Used for:
- Discovering VPN DNS endpoints
- Applying VPN-specific routing rules

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `STATE_DIR` | /run/agentic-route | Daemon state directory |
| `INTENT_FILE` | /etc/agentic-route/routes.json | Intent file path |
| `DEBOUNCE_MS` | 200 | Debounce interval in milliseconds |

EOF 2>&1
