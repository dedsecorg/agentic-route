---
title: Container Deployment
description: Running agentic-route in containers
---

# Container Deployment

## GHCR Images

Multi-architecture images (linux/amd64, linux/arm64) published to GitHub Container Registry.

```bash
# Pinned release (recommended for CI)
docker pull ghcr.io/dedsecorg/agentic-route:1.0.0

# Moving major release
docker pull ghcr.io/dedsecorg/agentic-route:v1

# Latest from master
docker pull ghcr.io/dedsecorg/agentic-route:latest
```

## Running

Requires NET_ADMIN capability and host network:

```bash
# Query status
docker run --rm   --cap-add=NET_ADMIN   --network=host   ghcr.io/dedsecorg/agentic-route:v1 status

# Run reconciliation
docker run --rm   --cap-add=NET_ADMIN   --network=host   ghcr.io/dedsecorg/agentic-route:v1 reconcile

# Run daemon
docker run -d   --name agentic-route   --restart unless-stopped   --cap-add=NET_ADMIN   --network=host   -v /etc/agentic-route:/etc/agentic-route   ghcr.io/dedsecorg/agentic-route:v1 daemon
```

## Volumes

| Host Path | Container Path | Description |
|-----------|----------------|-------------|
| /etc/agentic-route | /etc/agentic-route | Intent file and config |

## Build Locally

```bash
docker build -t agentic-route .
```

EOF 2>&1
