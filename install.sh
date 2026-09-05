#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 dedsecorg
set -euo pipefail
PREFIX="${PREFIX:-/usr/local}"
sudo -S -p '' install -Dm755 bin/agentic-route "$PREFIX/bin/agentic-route"
sudo -S -p '' install -Dm755 bin/agentic-route-reconcile "$PREFIX/bin/agentic-route-reconcile"
sudo -S -p '' install -Dm755 bin/agentic-route-daemon "$PREFIX/bin/agentic-route-daemon"
sudo -S -p '' install -Dm644 lib/core.sh /usr/local/lib/agentic-route/core.sh
sudo -S -p '' install -Dm644 etc/routes.json.example /etc/agentic-route/routes.json.example
sudo -S -p '' install -Dm644 etc/intent.json.example /etc/agentic-route/intent.json.example
sudo -S -p '' install -Dm644 etc/agentic-route.service /etc/systemd/system/agentic-route.service
sudo -S -p '' install -Dm644 etc/agentic-route-daemon.service /etc/systemd/system/agentic-route-daemon.service
if [ ! -f /etc/agentic-route/routes.json ]; then
    sudo -S -p '' install -Dm644 etc/routes.json.example /etc/agentic-route/routes.json
fi
if [ ! -f /etc/agentic-route/intent.json ]; then
    sudo -S -p '' install -Dm644 etc/intent.json.example /etc/agentic-route/intent.json
fi
sudo -S -p '' systemctl daemon-reload
echo "agentic-route installed at $PREFIX/bin/agentic-route"
echo "agentic-route-reconcile installed at $PREFIX/bin/agentic-route-reconcile"
echo "agentic-route-daemon installed at $PREFIX/bin/agentic-route-daemon"

