# REST API

## Starting the Server

```bash
agentic-route api
# Listens on port 8099 (configurable via AGENTIC_ROUTE_API_PORT)
```

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/status` | Full service status (live + desired rules/routes) |
| `GET` | `/api/v1/check` | Drift detection: `{"clean": true/false}` |
| `GET` | `/api/v1/enforce` | Apply reconciliation: `{"enforced": true}` |
| `GET` | `/api/v1/diff` | Precise diff (same as CLI `diff`) |

## Examples

```bash
# Check drift
curl http://localhost:8099/api/v1/check
# {"clean": false}

# Get full status
curl http://localhost:8099/api/v1/status
# {"status": "ok", "text": "agentic-route status
Spec: /etc/agentic-route/routes.json
--- Desired rules ---
..."}

# Enforce reconciliation
curl http://localhost:8099/api/v1/enforce
# {"enforced": true}
```

## Implementation

Uses `socat` for TCP listening, delegates to CLI subcommands:

```bash
cmd_api() {
    local port="${AGENTIC_ROUTE_API_PORT:-8099}"
    if ! command -v socat >/dev/null 2>&1; then
        ar_die "socat is required for api"
    fi
    ar_log "API listening on :$port"
    while true; do
        socat TCP-LISTEN:"$port",reuseaddr,fork SYSTEM:"$0 api-handler" 2>/dev/null
    done
}

cmd_api_handler() {
    local path
    IFS=' ' read -r _ path _ || true
    printf 'HTTP/1.1 200 OK
Content-Type: application/json

'
    case "$path" in
        /api/v1/status) cmd_status 2>&1 | jq -Rs '{status:"ok", text:.}';;
        /api/v1/check) cmd_check >/dev/null 2>&1; printf '{"clean":%s}
' "$([ "$?" -eq 0 ] && echo true || echo false)";;
        /api/v1/enforce) cmd_enforce >/dev/null 2>&1; echo '{"enforced":true}';;
        *) echo '{"error":"not found"}';;
    esac
}
```

