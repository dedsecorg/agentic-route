# agentic-route

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Protocol: MCP](https://img.shields.io/badge/MCP-JSON--RPC-success.svg)](docs/MCP_GUIDE.md)
[![Platform: Linux](https://img.shields.io/badge/Platform-Linux-blue.svg)](docs/ARCHITECTURE.md)

> Declarative kernel policy-routing reconciler for agentic systems.

`agentic-route` is the IP-routing sibling of `agentic-dns`: a small, FOSS,
POSIX-Bash state handler that keeps Linux `ip rule` and `ip route` state aligned
with a hand-edited JSON specification. It watches rtnetlink events so VPN
daemons cannot silently clobber policy priorities or pinned egress routes.

## Quick Installation

### One-line installer

```bash
curl -fsSL https://raw.githubusercontent.com/dedsecorg/agentic-route/main/install.sh | bash
```

### From a checkout

```bash
sudo ./install.sh
sudoedit /etc/agentic-route/routes.json
sudo systemctl enable --now agentic-route
```

## 60-Second AI Onboarding

```bash
claude mcp add agentic-route agentic-route mcp
```

Or add this to `.mcp.json`:

```json
{
  "mcpServers": {
    "agentic-route": {
      "command": "agentic-route",
      "args": ["mcp"],
      "env": {"AGENTIC_ROUTE_CONF": "/etc/agentic-route/routes.json"}
    }
  }
}
```

MCP exposes `route_status`, `route_check`, `route_enforce`, and
`route_monitor`.

## CLI Quick Reference

```bash
agentic-route status
agentic-route check
sudo agentic-route enforce
sudo agentic-route monitor
agentic-route mcp
agentic-route api
```

`check` is read-only and exits 0 when clean or 1 when drift exists. The
default command is `enforce`. The configuration path is controlled by
`AGENTIC_ROUTE_CONF`, or defaults to `/etc/agentic-route/routes.json`.

## Architecture

The engine reads the declarative `rules`, `forbidden_rules`, and
`pinned_routes` arrays, compares them with canonical IPv4 output from iproute2,
and performs only guarded adds, deletes, and route replacements. It never
flushes a table or rule set. `monitor` performs a baseline reconciliation, then
subscribes to `ip monitor rule route link` with a short debounce.

See [the architecture specification](docs/ARCHITECTURE.md) and
[the MCP guide](docs/MCP_GUIDE.md).

## License

MIT License. See [LICENSE](LICENSE).
