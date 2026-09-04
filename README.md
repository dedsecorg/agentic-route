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

## net-safe: the deadman switch

`agentic-route` reconciles the *eventual* steady state. `net-safe` protects the
*transition*: when an agent (or human) is about to run a raw `ip rule`,
`ip route`, or `iptables` change in the root namespace, it arms a timer and
snapshots the full routing state. If nobody confirms within N seconds, it
restores everything automatically - so a bad rule that severs the agent's own
transport unwinds itself instead of locking the operator out.

```bash
net-safe arm 30       # snapshot everything + arm a 30s fuse
ip rule add ...       # <-- the risky change
# if you can still reach the network:
net-safe confirm      # keep the changes, disarm
# or, if something went wrong:
net-safe rollback     # restore now (manual abort)
net-safe status       # is the fuse armed?
```

The standard agent pattern (commit-confirmed, like Junos `commit confirmed`):

```bash
net-safe arm 30
# apply the experimental network change
if ping -c1 -W2 1.1.1.1 >/dev/null 2>&1; then
    net-safe confirm
else
    net-safe rollback
fi
```

If the change severs the default route, the `ping` never runs and the agent's
session freezes - but the detached timer still hits 30s, replays the snapshot,
and the host snaps back online with no out-of-band console.

Design invariants:

- **Full snapshot replay** - restores `ip rule`, every `ip route` table,
  `iptables`, and `rp_filter`. It never does a partial restore.
- **SIGHUP-survival** - the timer runs under `setsid` + `nohup`, so it keeps
  ticking after the session that armed it is severed.
- **Zero hardcoded identity** - the lifeline device/gateway are auto-detected
  from the default route (override with `NETSAFE_DEV` / `NETSAFE_GW`).
- **Coherence guard** - refuses to arm over an empty or broken snapshot.

## License

MIT License. See [LICENSE](LICENSE).
