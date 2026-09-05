# Installation

## Manual (Recommended for Servers)

```bash
git clone https://github.com/dedsecorg/agentic-route
cd agentic-route
sudo -S -p '' ./install.sh
```

### What Gets Installed

| Path | Purpose |
|------|---------|
| `/usr/local/bin/agentic-route` | Main CLI |
| `/usr/local/bin/agentic-route-reconcile` | Idempotent one-shot reconciliation |
| `/usr/local/bin/agentic-route-daemon` | Event-driven daemon |
| `/usr/local/lib/agentic-route/core.sh` | Reconciliation engine |
| `/etc/agentic-route/intent.json` | Your routing intent (edit this) |
| `/etc/agentic-route/routes.json` | Legacy spec (deprecated, use intent.json) |
| `/etc/systemd/system/agentic-route.service` | Legacy systemd unit |
| `/etc/systemd/system/agentic-route-daemon.service` | **New** hardened systemd unit |

### Enable Daemon

```bash
sudo -S -p '' systemctl enable --now agentic-route-daemon
```

## Smithery (For MCP Clients)

```bash
npx -y @smithery/cli install @dedsecorg/agentic-route
```

## Requirements

- Linux kernel 4.19+ (Netlink `ip monitor`)
- `iproute2` (`ip`, `jq`)
- `inotify-tools` (`inotifywait`)
- `bash` 4.4+
- `CAP_NET_ADMIN` (for daemon)

