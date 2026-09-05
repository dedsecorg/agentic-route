# Multi-VPN Example

## Problem

Three VPNs managing routing simultaneously:
- **NordVPN** — primary egress (table 205, fwmark 0xe1f1)
- **ProtonVPN** — DNS only (interface `proton0`, DNS 10.2.0.1)
- **Tailscale** — mesh network (CGNAT 100.64.0.0/10, table 52)

Without coordination: traffic leaks, SSH freezes, mesh routes through wrong interface.

## Solution: `intent.json`

```json
{
  "version": 1,
  "comment": "Multi-VPN stack: NordVPN egress, ProtonVPN DNS, Tailscale mesh",
  "forbidden_rules": [
    { "prio": 31580, "match": "suppress_prefixlength 0", "reason": "Proton suppress-bypass rule (ride-along with its capture)" },
    { "prio": 31581, "match": "lookup 245447468", "reason": "Proton split-tunnel capture: Proton is DNS-only, must not own host egress" },
    { "match": "100.64.0.0/10 lookup main", "reason": "Tailscale hijack: mesh CIDR must never route via main table" }
  ],
  "pinned_routes": [
    { "dst": "194.126.177.6/32", "via": "185.170.112.1", "dev": "eth0", "reason": "Pin Proton WG endpoint through eth0 so tunnel never loses handshake" },
    { "dst": "10.2.0.1/32", "dev": "proton0", "comment": "Proton DNS resolver strictly out proton0" },
    { "dst": "default", "via": "185.170.112.1", "dev": "eth0", "comment": "Bare-metal fallback egress (never let VPNs remove it)" }
  ],
  "custom_rules": [
    { "prio": 480, "selector": "from all to 100.64.0.0/10", "action": "lookup 52" },
    { "prio": 32765, "selector": "not from all fwmark 0xe1f1", "action": "lookup 205" }
  ]
}
```

## Result

| Traffic | Path |
|---------|------|
| ProtonVPN DNS | `proton0` -> 10.2.0.1 (pinned) |
| Tailscale mesh (100.64.0.0/10) | table 52 (custom_rule 480) |
| NordVPN egress | table 205 via fwmark 0xe1f1 (custom_rule 32765) |
| Proton WG handshake | eth0 -> 194.126.177.6 (pinned) |
| Fallback egress | eth0 -> default via 185.170.112.1 (pinned) |
| Proton capture rules | Removed (forbidden_rules 31580, 31581) |
| Tailscale hijack | Blocked (forbidden_rules generic) |

## Priority Map

| Priority | Rule | Purpose |
|----------|------|---------|
| 480 | Tailscale CGNAT -> table 52 | Mesh traffic isolated |
| 31580 | (forbidden) Proton suppress | VPN capture prevention |
| 31581 | (forbidden) Proton split-tunnel | VPN capture prevention |
| 5000-5270 | fwmark routing | NordVPN policy routing |
| 32765 | NordVPN default egress | Main traffic out NordVPN |
| 32766-32767 | Local/main/default | Kernel defaults |

