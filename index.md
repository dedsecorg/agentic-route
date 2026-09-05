---
layout: default
---
# agentic-route

**Declarative kernel policy-routing reconciler.** Define desired routing state in JSON; the daemon continuously reconciles the Linux kernel routing tables and policy rules to match — idempotent, event-driven, zero-config drift detection.

[![Release](https://img.shields.io/github/v/release/dedsecorg/agentic-route?color=blue&logo=github)](https://github.com/dedsecorg/agentic-route/releases)
[![GHCR Image](https://img.shields.io/badge/ghcr.io-dedsecorg%2Fagentic--route-24292e?logo=docker)](https://github.com/dedsecorg/agentic-route/pkgs/container/agentic-route)
[![Multi-Arch](https://img.shields.io/badge/arch-amd64%20%7C%20arm64-blue)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Context7](https://img.shields.io/badge/Context7-Indexed-brightgreen)](https://context7.com/dedsecorg/agentic-route)

## Quick Start

```bash
git clone https://github.com/dedsecorg/agentic-route
cd agentic-route
sudo -S -p '' ./install.sh
```

## Documentation

- [Installation](docs/installation.md)
- [Architecture](docs/architecture.md)
- [MCP Integration](docs/mcp-guide.md)
- [Commands](docs/commands.md)
- [Intent File](docs/intent-file.md)

## OCI Container (GHCR)

```bash
# Pinned release
docker pull ghcr.io/dedsecorg/agentic-route:1.0.0

# Moving major release
docker pull ghcr.io/dedsecorg/agentic-route:v1

# Latest from master
docker pull ghcr.io/dedsecorg/agentic-route:latest
```

## Context7

This repository is indexed on [Context7](https://context7.com/dedsecorg/agentic-route) with 148 code snippets for AI-assisted development. The Context7 chat widget is available on this site (bottom-right button).

EOF 2>&1
