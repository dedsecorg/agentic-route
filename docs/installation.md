---
layout: default
title: Installation
---

# Installation

## Manual

```bash
git clone https://github.com/dedsecorg/agentic-route
cd agentic-route
sudo -S -p '' ./install.sh
```

Installs:
- `/usr/local/bin/agentic-route` — main CLI
- `/usr/local/bin/agentic-route-reconcile` — one-shot reconciler
- `/usr/local/bin/agentic-route-daemon` — event-driven daemon
- `/etc/agentic-route/` — config directory
- `/etc/systemd/system/agentic-route.service` — systemd unit

## Requirements

- Linux (systemd, nftables/iptables)
- `iproute2`, `jq`, `bash` 4.4+
- `CAP_NET_ADMIN`, `CAP_NET_BIND_SERVICE`

EOF 2>&1
