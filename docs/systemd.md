---
title: systemd Service
description: Running agentic-route as a systemd service
---

# systemd Service

## Installation

The `install.sh` script creates systemd units:

```bash
sudo -S -p '' ./install.sh
```

## Service Files

### agentic-route.service

```ini
[Unit]
Description=agentic-route daemon
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/agentic-route-daemon
Restart=on-failure
RestartSec=5
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
```

### Enable and Start

```bash
sudo -S -p '' systemctl enable agentic-route
sudo -S -p '' systemctl start agentic-route
sudo -S -p '' systemctl status agentic-route
```

## Logs

```bash
journalctl -u agentic-route -f
journalctl -u agentic-route --since "1 hour ago"
```

## Daemon Behavior

- Watches `/etc/agentic-route/routes.json` for changes (inotifywait)
- Debounced reconciliation (200ms default)
- Idempotent: only applies changes when drift detected
- Updates `/run/agentic-route/state.json` with current state

EOF 2>&1
