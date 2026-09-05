#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 dedsecorg
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/bin/agentic-route"
CONF="$(mktemp "$ROOT/.test-routes.XXXXXX")"
trap 'rm -f "$CONF"' EXIT
printf '%s\n' '{"version":1,"rules":[],"forbidden_rules":[],"pinned_routes":[]}' > "$CONF"
export AGENTIC_ROUTE_CONF="$CONF"
bash -n "$BIN" "$ROOT/lib/core.sh" "$ROOT/install.sh"
"$BIN" status >/dev/null
"$BIN" check
printf '%s\n' '{"version":1,"rules":[{"prio":99,"selector":"from 192.0.2.10","action":"lookup main"}],"forbidden_rules":[],"pinned_routes":[]}' > "$CONF"
if "$BIN" check >/dev/null 2>&1; then
    echo "check failed to report drift" >&2
    exit 1
fi
echo "agentic-route tests passed"
