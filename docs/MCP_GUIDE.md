# Model Context Protocol Guide

agentic-route includes a native stdio MCP JSON-RPC server.

## Clients

- Claude Code: `claude mcp add agentic-route agentic-route mcp`
- Cursor, Windsurf, and Copilot: add `mcp/mcp_server.json` to the client configuration.
- Hermes Agent: register the same manifest.

## Tools

- `route_status`: Show the desired specification and live IPv4 state.
- `route_check`: Report drift without mutation.
- `route_enforce`: Apply surgical reconciliation.
- `route_monitor`: Explain how to start the long-running monitor.

The transport is stdio. Supported methods are `initialize`, `ping`,
`tools/list`, and `tools/call`.
