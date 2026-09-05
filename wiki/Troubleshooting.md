# Troubleshooting

## Daemon Not Starting

```bash
# Check logs
journalctl -u agentic-route-daemon -n 50 --no-pager

# Common issues:
# 1. inotify-tools not installed
sudo -S -p '' apt-get install inotify-tools

# 2. Missing CAP_NET_ADMIN
# Check service file has:
# CapabilityBoundingSet=CAP_NET_ADMIN
# AmbientCapabilities=CAP_NET_ADMIN

# 3. FIFO cleanup from previous crash
ls -la /run/agentic-route/
# Remove stale FIFO if needed:
rm -f /run/agentic-route/events.fifo
```

## Drift Not Being Corrected

```bash
# Run one-shot to see output
agentic-route-reconcile

# Check state
cat /run/agentic-route/state.json | jq .

# Verify intent.json is valid JSON
jq . /etc/agentic-route/intent.json
```

## VPN Reconnect Breaks Routing

The daemon should catch this via `ip monitor`. If not:

```bash
# Force reconcile
agentic-route enforce

# Or restart daemon
systemctl restart agentic-route-daemon
```

## High CPU Usage

```bash
# Check if debounce is working
# Should see ~0% CPU idle, spikes only on events
top -p $(systemctl show agentic-route-daemon --property=MainPID --value)

# If high CPU: check for runaway loop
journalctl -u agentic-route-daemon -f
# Look for rapid "kernel routing event" logs without debounce
```

## Debug Mode

```bash
# Run daemon in foreground with verbose output
HR_QUIET=0 /usr/local/bin/hermes-route-daemon

# Or run reconcile with debug
HR_QUIET=0 HR_DIFF_MODE=check /usr/local/bin/agentic-route-reconcile
```

## Common Patterns

| Symptom | Cause | Fix |
|---------|-------|-----|
| SSH freezes on Android | MTU mismatch (1280 vs 1360) | `Environment=TS_MTU=1360` in `systemctl edit tailscaled` |
| ProtonVPN steals egress | Priority 31581 capture rule | Forbidden rule in intent.json |
| Tailscale routes via main | Missing rule 480 | Custom rule in intent.json |
| Default route disappears | VPN flushes on reconnect | Pinned default route in intent.json |

