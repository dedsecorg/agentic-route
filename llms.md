# agentic-route LLM Reference

agentic-route is the IP-routing sibling of agentic-dns. It reconciles a
hand-edited JSON state specification with Linux kernel policy routing.

Commands are `status`, `check`, `diff`, `trace`, `enforce`, `monitor`,
`daemon`, `reconcile`, `mcp`, and `api`. The default is `enforce`. `check` is
read-only and returns 1 on drift. The CLI spec is `AGENTIC_ROUTE_CONF`
(`/etc/agentic-route/routes.json`); the reconciler/daemon read intent from
`AGENTIC_ROUTE_INTENT` (`/etc/agentic-route/intent.json`).

The engine uses `ip`, `jq`, `awk`, and standard POSIX tools. It listens to
`ip monitor rule route link`, uses a short debounce, and never flushes rules or
routes. MCP (`agentic-route mcp`, stdio) is read-only: `route_status`,
`route_check`, `route_diff`, `route_trace`. Mutation over the network is only
available via the mTLS REST API (`agentic-route api`, client cert required).
