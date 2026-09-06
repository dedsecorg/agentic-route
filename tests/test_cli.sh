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
bash -n "$ROOT/bin/agentic-route-reconcile" "$ROOT/bin/agentic-route-daemon" "$ROOT/bin/net-safe"

# MCP contract: read-only, exactly four tools, JSON-RPC errors for bad input
MCP_OUT=$(printf '%s\n' \
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
    '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
    '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
    '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"route_check","arguments":{}}}' \
    '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"route_trace","arguments":{}}}' \
    '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"route_enforce","arguments":{}}}' \
    '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"route_trace","arguments":{"target":"256.1.1.1"}}}' \
    | "$BIN" mcp 2>/dev/null)
[ "$(printf '%s\n' "$MCP_OUT" | wc -l)" -eq 6 ] || { echo "mcp: expected 6 responses (notification must be ignored)" >&2; exit 1; }
mcp_has() { printf '%s\n' "$MCP_OUT" | jq -se "any($1)" >/dev/null || { echo "mcp: assertion failed: $1" >&2; exit 1; }; }
mcp_has '.id==1 and (.result.protocolVersion|type)=="string"'
[ "$(printf '%s\n' "$MCP_OUT" | jq -r 'select(.id==2) | .result.tools[].name' | sort | tr '\n' ' ')" = "route_check route_diff route_status route_trace " ] \
    || { echo "mcp: tools/list must expose exactly the four read-only tools" >&2; exit 1; }
mcp_has '.id==3 and (.result.content[0].text|test("drift detected"))'
mcp_has '.id==4 and .error.code==-32602'
mcp_has '.id==5 and .error.code==-32601'
mcp_has '.id==6 and .result.isError==true'

# REST handler emits CRLF HTTP headers
HTTP_OUT=$("$BIN" api-handler <<< $'GET /api/v1/nope HTTP/1.1\r')
[ "${HTTP_OUT%%$'\n'*}" = $'HTTP/1.1 404 Not Found\r' ] || { echo "api-handler: expected CRLF 404 status line" >&2; exit 1; }

echo "agentic-route tests passed"
