# Agentic DNS

**Agentic AI-Native DNS Routing, Diagnostics & Telemetry.** Manages a complete DNS resolution chain (Pi-hole -> CoreDNS -> dnsdist -> Unbound/Stubby/DNSCrypt -> VPN DNS) with CLI, REST API, stdio MCP, and a Rust DoT/mTLS proxy server.

## Quick Links
- [GitHub Repository](https://github.com/dedsecorg/agentic-dns)
- [README](https://github.com/dedsecorg/agentic-dns#readme)

## Integration with agentic-route

| Layer | Tool | Purpose |
|-------|------|---------|
| L3 (Routing) | agentic-route | Kernel policy routing, VPN traffic steering |
| L7 (DNS) | agentic-dns | DNS chain orchestration, DoT/DoH proxy |

Both use the same architectural patterns:
- Declarative intent files
- Event-driven daemons (inotify + Netlink)
- FIFO multiplexing with debounce
- Read-only MCP servers
- REST APIs

## Shared Infrastructure

```
+------------------+     +------------------+
|  agentic-route   |     |  agentic-dns     |
|  (L3 routing)    |     |  (L7 DNS)        |
+--------+---------+     +--------+---------+
         |                       |
         |  Tailscale mesh       |  Pi-hole blocking
         |  NordVPN egress       |  CoreDNS split-horizon
         |  ProtonVPN DNS        |  dnsdist load balance
         v                       v
+----------------------------------------------+
|           Linux Kernel                       |
|  ip rule/route + nftables/iptables           |
+----------------------------------------------+
```

