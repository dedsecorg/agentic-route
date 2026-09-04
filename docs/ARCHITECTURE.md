# agentic-route Architecture

## Purpose

agentic-route is a declarative state handler, not a source of truth. An
operator owns `routes.json`; the process reads it and reconciles live Linux
kernel state back to it.

## Reconciliation

The Bash core obtains canonical IPv4 rules with `ip -4 rule show` and routes
with `ip -4 route show`. Missing declared rules are added only after a
check-then-act lookup. Forbidden rules are deleted only when their match
substring aligns, with an optional exact priority gate. Pinned routes use
`ip route replace` after checking their destination, gateway, and device.

No command uses `ip rule flush` or `ip route flush`.

## Event Loop

`monitor` first reconciles, then consumes `ip monitor rule route link`.
Events are debounced by approximately 200 milliseconds before another
reconciliation. `daemon` is an alias intended for systemd.

## Configuration

The JSON schema contains `rules`, `forbidden_rules`, and `pinned_routes`.
iproute2 canonical vocabulary matters: selectors and actions are stored as the
same text emitted by `ip rule show`, while host route `/32` suffixes normalize
to the bare address during matching.
