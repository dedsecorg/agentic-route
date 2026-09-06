---
layout: default
title: PKI / mTLS operations
---

# PKI / mTLS operations

The only network-reachable control surface in agentic-route is the REST API,
and it requires a client certificate. `/api/v1/enforce` mutates kernel
routing, so it must never be reachable unauthenticated.

| Surface | Process | Cert / key / CA (defaults) |
|---------|---------|----------------------------|
| REST API `:8099` | `agentic-route api` (socat `OPENSSL-LISTEN`) | `AGENTIC_ROUTE_TLS_CERT` / `AGENTIC_ROUTE_TLS_KEY` / `AGENTIC_ROUTE_TLS_CA` → `/etc/agentic-route/certs/{api.crt,api.key,ca.crt}` |

The MCP server (`agentic-route mcp`) is stdio-only and read-only; it has no
network listener and needs no certificate.

The sibling project agentic-dns uses the same layout under
`/etc/agentic-dns/certs/` (`AGENTIC_DNS_TLS_*`, plus the Rust DoT proxy).
One CA can sign both.

Only *paths* are configurable. Key material lives in `/etc/agentic-*/certs/`
(mode `0700`, root-owned) and is never committed. There is no fallback: if a
file is missing or unreadable the listener refuses to start rather than fall
back to plaintext.

## Threat model

- **Authentication** — X.509 client certs. A peer without a cert chaining to
  `ca.crt` is rejected during the TLS handshake, before any handler code runs
  (socat spawns `api-handler` only after `verify=1` passes). Bash header
  parsing is never on the auth path.
- **Harvest-now-decrypt-later** — the socat surface is pinned to TLS 1.3 and
  inherits whatever key-exchange groups the host OpenSSL offers: OpenSSL ≥ 3.5
  negotiates hybrid post-quantum X25519MLKEM768 by default; older OpenSSL
  gives classical TLS 1.3 mTLS now and PQ on upgrade, with no config change.
  If uniform PQ is required before the host OpenSSL is upgraded, front the API
  with the agentic-dns Rust server (aws-lc-rs, X25519MLKEM768 enforced).
- **Certificates stay classical** (ECDSA P-256 / Ed25519). HNDL is a
  key-exchange problem; signatures only need to be unforgeable *today*, and
  can be rotated onto PQ signature schemes when clients support them.

## Generate the PKI (openssl CLI, no other tooling)

Run as root on the host that owns the services. Use a short-lived CA key
(kept offline if possible) and a per-service server cert.

```bash
umask 077
install -d -m 0700 /etc/agentic-route/certs /etc/agentic-route/certs/clients
cd /etc/agentic-route/certs

# 1. CA (10 years). Keep ca.key offline after issuing.
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
  -days 3650 -subj "/CN=agentic-ca" -keyout ca.key -out ca.crt

# 2. One server cert per service (1 year). SAN must cover how clients dial it.
for svc in api; do
  openssl req -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
    -subj "/CN=agentic-route-$svc" \
    -addext "subjectAltName=DNS:$(hostname),IP:127.0.0.1" \
    -keyout $svc.key -out $svc.csr
  openssl x509 -req -in $svc.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -days 365 -copy_extensions copy -out $svc.crt
  rm -f $svc.csr
done

# 3. One client cert per agent (90 days). Ship <agent>.crt+key to the agent
#    only; the CA never leaves this directory.
agent=hermes
openssl req -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
  -subj "/CN=agent-$agent" -keyout clients/$agent.key -out clients/$agent.csr
openssl x509 -req -in clients/$agent.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -days 90 -out clients/$agent.crt
```

Keys are PKCS#8 PEM (`openssl req -newkey` default); the Rust loader accepts
PKCS#8, SEC1 and PKCS#1.

## Using a client cert

```bash
curl --cacert /etc/agentic-route/certs/ca.crt \
     --cert ~/.agentic/hermes.crt --key ~/.agentic/hermes.key \
     https://127.0.0.1:8099/api/v1/status

```

Verify the surface rejects unauthenticated peers:

```bash
curl --cacert ca.crt https://127.0.0.1:8099/api/v1/status; echo "rc=$?"
# expect: rc=56 (TLS handshake failure, handler never spawned)
```

## Rotation

- **Client certs (90 d):** issue a new cert for the agent (step 3), swap on
  the agent, done. Both old and new are valid until expiry; no server restart.
- **Server certs (1 y):** re-run step 2 for the service, then restart it
  (`systemctl restart agentic-route-api`). socat reads the files at
  start-up only.
- **CA (10 y):** create a new CA, issue new server certs, and append the new
  CA to `ca.crt` (it is a bundle — OpenSSL `cafile` accepts concatenated
  PEM) so old and new clients overlap. Re-issue
  client certs, then drop the old CA from the bundle and restart.

## Revocation

There is no CRL/OCSP wiring by design (no new dependencies). Revocation is:

1. **Short lifetimes.** 90-day client certs bound the blast radius.
2. **CA roll.** To revoke one client immediately, roll the CA (above) and
   re-issue every *other* client. With a handful of agents this is minutes.
3. **Emergency:** delete `ca.crt` and restart the service — every peer is
   refused until a CA is restored (fail closed).

Because the REST API only binds on loopback / Tailscale, a
compromised client cert still requires network reachability to be abused.

## Checklist for a new host

```bash
socat -V | grep -q OPENSSL || echo "socat lacks OpenSSL: API cannot start"
openssl version                              # >= 3.5 for PQ KEM on the socat surface
openssl list -kem-algorithms | grep -qi mlkem && echo "PQ hybrid available to socat"
ls -l /etc/agentic-route/certs                 # 0700 dir, 0600 keys
agentic-route api &                          # must log "mTLS"
```
