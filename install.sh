#!/bin/bash
set -euo pipefail
PREFIX="${PREFIX:-/usr/local}"
sudo install -Dm755 bin/agentic-route "$PREFIX/bin/agentic-route"
sudo install -Dm644 lib/core.sh /usr/local/lib/agentic-route/core.sh
sudo install -Dm644 etc/routes.json.example /etc/agentic-route/routes.json.example
sudo install -Dm644 etc/agentic-route.service /etc/systemd/system/agentic-route.service
if [ ! -f /etc/agentic-route/routes.json ]; then
    sudo install -Dm644 etc/routes.json.example /etc/agentic-route/routes.json
fi
sudo systemctl daemon-reload
echo "agentic-route installed at $PREFIX/bin/agentic-route"
