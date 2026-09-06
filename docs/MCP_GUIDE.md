# Model Context Protocol Guide

agentic-route includes a native stdio MCP JSON-RPC server. It is
**read-only** by design: an agent can inspect routing state and drift but
cannot change kernel state through MCP. Mutation stays with the CLI
(`agentic-route enforce`, `agentic-route-reconcile`) or the mTLS REST API.

## Clients

- Claude Code: `claude mcp add agentic-route agentic-route mcp`
- Cursor, Windsurf, and Copilot: add `mcp/mcp_server.json` to the client configuration.
- Hermes Agent: register the same manifest.

## Tools

- `route_status`: Desired specification vs live IPv4 rules/routes, with drift count.
- `route_check`: Report drift without mutation.
- `route_diff`: Precise would-add / would-del / would-replace listing.
- `route_trace`: `ip route get <target> [from <src>]`.

The transport is stdio. Supported methods are `initialize`, `ping`,
`tools/list`, and `tools/call`. The spec file is `AGENTIC_ROUTE_CONF`
(default `/etc/agentic-route/routes.json`).

See [api-reference.md](api-reference.md) for the full contract.
