#!/usr/bin/env bash
set -euo pipefail

NETWORK_NAME="agents-net"

if docker network inspect "$NETWORK_NAME" &>/dev/null; then
    echo "  ✓ Docker network '${NETWORK_NAME}' already exists"
else
    docker network create \
        --driver bridge \
        --opt com.docker.network.bridge.name=br-agents \
        "$NETWORK_NAME"
    echo "  ✓ Created Docker network '${NETWORK_NAME}'"
fi
