# Security Hardening

## Systemd Unit Hardening (`agentic-route-daemon.service`)

```ini
[Service]
Type=simple
ExecStart=/usr/local/bin/agentic-route-daemon
Restart=always
RestartSec=2
CapabilityBoundingSet=CAP_NET_ADMIN
AmbientCapabilities=CAP_NET_ADMIN
ProtectSystem=strict
ReadWritePaths=/run/agentic-route /etc/agentic-route
NoNewPrivileges=yes
```

| Setting | Purpose |
|---------|---------|
| `CapabilityBoundingSet=CAP_NET_ADMIN` | Only NET_ADMIN capability (routing changes) |
| `AmbientCapabilities=CAP_NET_ADMIN` | Retains capability after exec |
| `ProtectSystem=strict` | Mount `/usr`, `/boot`, `/etc` read-only |
| `ReadWritePaths=/run/agentic-route /etc/agentic-route` | Only these dirs writable |
| `NoNewPrivileges=yes` | Prevents privilege escalation via exec |

## Least Privilege

- Daemon runs as `root` (required for `ip rule/route`)
- Only `CAP_NET_ADMIN` granted — no `CAP_SYS_ADMIN`, `CAP_DAC_OVERRIDE`, etc.
- State directory in tmpfs (`/run/agentic-route/`) — no persistent disk writes
- Intent file in `/etc/agentic-route/` — admin-only writable

## Attack Surface

| Vector | Mitigation |
|--------|------------|
| Malicious intent.json | Only root can write `/etc/agentic-route/intent.json` |
| FIFO injection | FIFO in `/run/agentic-route/` (tmpfs, root-only) |
| Netlink spoofing | Kernel validates Netlink messages; only root can inject |
| Binary replacement | Binaries in `/usr/local/bin/` (root-only write) |

## Audit Commands

```bash
# Verify capabilities
getcap /usr/local/bin/agentic-route-daemon
# Should show: =ep cap_net_admin+ep

# Verify systemd hardening
systemctl show agentic-route-daemon --property=CapabilityBoundingSet,AmbientCapabilities,ProtectSystem,ReadWritePaths,NoNewPrivileges

# Verify file permissions
ls -la /usr/local/bin/agentic-route* /usr/local/lib/agentic-route/
ls -la /etc/agentic-route/
ls -la /run/agentic-route/
```

