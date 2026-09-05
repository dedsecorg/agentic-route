---
layout: default
title: Intent File
---

# Intent File (`/etc/agentic-route/routes.json`)

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

EOF 2>&1
