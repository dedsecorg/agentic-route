# agentic-route

**Declarative kernel policy-routing reconciler.** Define desired routing state in JSON; the daemon continuously reconciles the Linux kernel routing tables and policy rules to match — event-driven, idempotent, and hardened for production.

[![Release](https://img.shields.io/github/v/release/dedsecorg/agentic-route?color=blue&logo=github)](https://github.com/dedsecorg/agentic-route/releases)
[![GHCR Image](https://img.shields.io/badge/ghcr.io-dedsecorg%2Fagentic--route-24292e?logo=docker)](https://github.com/dedsecorg/agentic-route/pkgs/container/agentic-route)
[![Multi-Arch](https://img.shields.io/badge/arch-amd64%20%7C%20arm64-blue)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Context7](https://img.shields.io/badge/Context7-Indexed-brightgreen)](https://context7.com/dedsecorg/agentic-route)

---

### OCI Container (GHCR)

Multi-architecture images (`linux/amd64`, `linux/arm64`) are published automatically on every semantic release.

#### Pulling the Image

```bash
# Pinned release (recommended for deterministic CI / sandboxes)
docker pull ghcr.io/dedsecorg/agentic-route:1.0.0

# Moving major release (auto-receives non-breaking fixes)
docker pull ghcr.io/dedsecorg/agentic-route:v1

# Latest build from default branch
docker pull ghcr.io/dedsecorg/agentic-route:latest
```

#### Running in Agent Sandboxes

Because routing reconciliation communicates directly with host Netlink sockets, the container requires the `NET_ADMIN` capability and host network namespace:

```bash
# Query routing state and status
docker run --rm \
  --cap-add=NET_ADMIN \
  --network=host \
  ghcr.io/dedsecorg/agentic-route:v1 status

# Run the reconciliation loop in daemon mode
docker run -d \
  --name agentic-route \
  --restart unless-stopped \
  --cap-add=NET_ADMIN \
  --network=host \
  -v /etc/hermes-route:/etc/hermes-route \
  ghcr.io/dedsecorg/agentic-route:v1 daemon
```

---

### Context7 Documentation

This repository is indexed on [Context7](https://context7.com/dedsecorg/agentic-route) with 148 code snippets for AI-assisted development. Use the Context7 MCP server or visit the link above for searchable documentation.

```bash
# Query via Context7 MCP
# "How to install agentic-route?"
# "agentic-route commands reference"
# "intent.json schema"
```

---

## Why This Exists

VPN daemons (NordVPN, ProtonVPN, Tailscale, WireGuard) fight over the kernel routing table. They add/remove `ip rule` and `ip route` entries on connect/disconnect, often clobbering each other. The result: traffic leaks, SSH freezes, DNS breaks, mesh networks route through the wrong interface.

**agentic-route** fixes this by treating routing as **declarative state**:

1. **You declare intent** (`/etc/agentic-route/intent.json`) — forbidden rules, pinned routes, custom rules
2. **Daemon discovers reality** — reads live `ip rule show` / `ip route show` via Netlink
3. **Reconciler computes delta** — desired = discovered + intent
4. **Applies surgically** — only `ip rule add/del` / `ip route replace` for actual drift
5. **Emits status** — writes `/run/agentic-route/state.json` with observed state + timestamp

---

## Architecture

```
+---------------------+     inotifywait      +------------------+
|  /etc/agentic-route/|<---------------------|  intent.json     |
|  (directory watch)  |   (survives vim)     |  (user intent)   |
+----------+----------+                      +------------------+
           |                                      ^
           | events                               | edit
           v                                      |
+---------------------+     ip monitor           |
|   FIFO multiplexer  |<--------------------------+
|  (exec 3<> "$FIFO") |   kernel Netlink
+----------+----------+
           | 200ms debounce
           v
+---------------------+
|  reconcile binary   |
|  (idempotent)       |
+----------+----------+
           | surgical ip rule/route
           v
+---------------------+
|  Kernel routing     |
|  tables + rules     |
+---------------------+
```

**Hardened against 5 classic Bash daemon bugs:**
- Subshell scope isolation -> single consumer loop in main process
- Netlink echo loop -> idempotent reconcile + debounce
- Burst storm (50 events/100ms) -> `read -t 0.2` drains burst
- inotify inode trap -> directory watch survives `vim` atomic rename
- FIFO EOF death -> `exec 3<> "$FIFO"` holds pipe open permanently

---

## Installation

### Manual (recommended for servers)
```bash
git clone https://github.com/dedsecorg/agentic-route
cd agentic-route
sudo -S -p '' ./install.sh
```
Installs:
- `/usr/local/bin/agentic-route` — main CLI
- `/usr/local/bin/agentic-route-reconcile` — idempotent one-shot
- `/usr/local/bin/agentic-route-daemon` — event-driven daemon
- `/usr/local/lib/agentic-route/core.sh` — reconciliation engine
- `/etc/agentic-route/intent.json` — your routing intent
- `/etc/systemd/system/agentic-route-daemon.service` — systemd unit

### Smithery (for MCP clients)
```bash
npx -y @smithery/cli install @dedsecorg/agentic-route
```

---

## Configuration

### `/etc/agentic-route/intent.json` — Your Routing Intent

```json
{
  "version": 1,
  "comment": "User intent only. Daemon writes discovered state to /run/agentic-route/state.json.",
  "forbidden_rules": [
    { "prio": 31580, "match": "suppress_prefixlength 0", "reason": "Remove VPN capture rule at this priority" },
    { "match": "100.64.0.0/10 lookup main", "reason": "Never let VPN redirect mesh CIDR through main table" }
  ],
  "pinned_routes": [
    { "dst": "198.51.100.7/32", "via": "192.0.2.1", "dev": "eth0", "reason": "Keep VPN endpoint reachable outside tunnel" },
    { "dst": "default", "via": "192.0.2.1", "dev": "eth0", "reason": "Bare-metal fallback egress" }
  ],
  "custom_rules": [
    { "prio": 480, "selector": "from all to 100.64.0.0/10", "action": "lookup 52" },
    { "prio": 32765, "selector": "not from all fwmark 0xe1f1", "action": "lookup 205" }
  ]
}
```

| Section | Purpose |
|---------|---------|
| `forbidden_rules` | Rules to **remove** if present. Optional `prio` gates deletion to exact priority (prevents catching lookalikes). |
| `pinned_routes` | Routes to **ensure exist**. Uses `ip route replace` — idempotent. |
| `custom_rules` | Rules to **add if missing**. Merged with discovered rules. |

---

## Commands

| Command | Description |
|---------|-------------|
| `agentic-route status` | Show desired vs live rules/routes + drift |
| `agentic-route check` | Exit 0 if clean, 1 if drift (no mutation) |
| `agentic-route diff` | Precise read-only diff: +add, -del, ~replace |
| `agentic-route trace <target> [from <src>]` | Trace packet path via `ip route get` |
| `agentic-route enforce` | One-shot surgical reconciliation |
| `agentic-route reconcile` | **Idempotent one-shot** (discovers + intent + applies) |
| `agentic-route daemon` | **Event-driven daemon** (inotify + ip monitor + FIFO) |
| `agentic-route monitor` | Legacy: `ip monitor | while read` loop |
| `agentic-route mcp` | Read-only stdio MCP JSON-RPC server |
| `agentic-route api` | Local REST API server (port 8099) |

### Daemon vs Reconcile

| | `reconcile` | `daemon` |
|---|-------------|----------|
| Trigger | Manual / cron | Events (file change + Netlink) |
| Latency | Immediate | < 200ms after event |
| Use case | CI, deploy hooks, on-demand | Continuous production |
| Idempotence | Strict | Strict |

---

## Systemd Service

```bash
sudo -S -p '' systemctl enable --now agentic-route-daemon
```

Hardened unit:
- `CAP_NET_ADMIN` only
- `ProtectSystem=strict`
- `ReadWritePaths=/run/agentic-route /etc/agentic-route`
- `Restart=always`, `RestartSec=2`
- Runs in tmpfs (`/run/agentic-route/`)

---

## MCP Integration

Start read-only MCP server:
```bash
agentic-route mcp
```

Tools exposed:
- `route_status` — live + desired rules/routes
- `route_check` — drift detection (boolean)
- `route_diff` — precise diff output
- `route_trace` — packet path tracing

Mutation (`enforce`) deliberately **not exposed** — apply path stays a CLI/operator action.

---

## Example: Multi-VPN Stack

**Problem:** NordVPN (egress), ProtonVPN (DNS only), Tailscale (mesh) all manage routing.

**Solution:** `intent.json`
```json
{
  "forbidden_rules": [
    { "prio": 31580, "match": "suppress_prefixlength 0", "reason": "Proton suppress-bypass" },
    { "prio": 31581, "match": "lookup 245447468", "reason": "Proton split-tunnel capture" },
    { "match": "100.64.0.0/10 lookup main", "reason": "Tailscale hijack prevention" }
  ],
  "pinned_routes": [
    { "dst": "194.126.177.6/32", "via": "185.170.112.1", "dev": "eth0" },
    { "dst": "10.2.0.1/32", "dev": "proton0" },
    { "dst": "default", "via": "185.170.112.1", "dev": "eth0" }
  ],
  "custom_rules": [
    { "prio": 480, "selector": "from all to 100.64.0.0/10", "action": "lookup 52" },
    { "prio": 32765, "selector": "not from all fwmark 0xe1f1", "action": "lookup 205" }
  ]
}
```

**Result:**
- ProtonVPN never owns host egress (DNS only via `proton0`)
- Tailscale mesh (100.64.0.0/10) -> table 52, never main
- NordVPN (fwmark 0xe1f1) owns default egress via table 205
- Proton WG endpoint pinned via eth0 (tunnel never loses handshake)
- Bare-metal default route survives VPN restarts

---

## Requirements

- Linux kernel 4.19+ (Netlink `ip monitor`)
- `iproute2` (`ip`, `jq`)
- `inotify-tools` (`inotifywait`)
- `bash` 4.4+
- `CAP_NET_ADMIN` (for daemon)

---

## License

MIT — see [LICENSE](LICENSE).

---

## Related

- **hermes-route** — private fork with real IPs, same engine