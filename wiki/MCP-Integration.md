# MCP Integration

## Starting the Server

```bash
agentic-route mcp
```

Runs a read-only stdio JSON-RPC 2.0 server. Compatible with Claude Desktop, Cursor, any MCP client.

## Tools Exposed

| Tool | Description | Input |
|------|-------------|-------|
| `route_status` | Show live and desired kernel rules and routes (read-only) | `{}` |
| `route_check` | Report whether routing has drifted from the spec (read-only, no mutation) | `{}` |
| `route_diff` | Precise diff of spec vs live: rules to add, forbidden rules to remove, pinned routes to replace (read-only) | `{}` |
| `route_trace` | Trace how a packet to a target IP would route, optionally from a source IP (read-only) | `{"target": "8.8.8.8", "source": "192.0.2.10"}` |

## Example Session

```json
// Client -> Server
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}

// Server -> Client
{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{"route_status":{...},"route_check":{...},"route_diff":{...},"route_trace":{...}}},"serverInfo":{"name":"agentic-route","version":"1.1.0"}}}

// Client -> Server
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"route_status","arguments":{}}}

// Server -> Client
{"jsonrpc":"2.0","id":2,"result":{"content":[{"type":"text","text":"agentic-route status
Spec: /etc/agentic-route/routes.json

--- Desired rules ---
  480: from all to 100.64.0.0/10 lookup 52
..."}]}}
```

## Design Decision: Read-Only MCP

Mutation (`enforce`, `reconcile`) is **deliberately not exposed** via MCP. The apply path stays a CLI/operator action wrapped by `net-safe` or manual execution. An MCP client can SEE and DIAGNOSE routing, but never change the kernel.

## Configuration for Claude Desktop

```json
{
  "mcpServers": {
    "agentic-route": {
      "command": "agentic-route",
      "args": ["mcp"]
    }
  }
}
```

