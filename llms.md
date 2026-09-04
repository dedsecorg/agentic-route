# agentic-route LLM Reference

agentic-route is the IP-routing sibling of agentic-dns. It reconciles a
hand-edited JSON state specification with Linux kernel policy routing.

Commands are `status`, `check`, `enforce`, `monitor`, `daemon`, `mcp`, and
`api`. The default is `enforce`. `check` is read-only and returns 1 on drift.
The configuration is `AGENTIC_ROUTE_CONF` or
`/etc/agentic-route/routes.json`.

The engine uses `ip`, `jq`, `awk`, and standard POSIX tools. It listens to
`ip monitor rule route link`, uses a short debounce, and never flushes rules or
routes. MCP tools are `route_status`, `route_check`, `route_enforce`, and
`route_monitor`.
