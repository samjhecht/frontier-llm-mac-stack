#!/bin/bash
# Frontier LLM Stack - Mistral.rs Stop Script
# 
# This script gracefully stops the Mistral.rs inference server.
#
# Usage:
#   ./mistral-stop.sh

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MISTRAL_DIR="$PROJECT_ROOT/stacks/mistral"

# Configuration
CONTAINER_NAME="frontier-mistral"
SHUTDOWN_TIMEOUT="${MISTRAL_SHUTDOWN_TIMEOUT:-30}"

echo "Stopping Mistral.rs inference server..."

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "Error: docker-compose is not installed or not in PATH"
    exit 1
fi

# Check if container is running
if ! docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null | grep -q "true"; then
    echo "Mistral is not running"
    exit 0
fi

# Stop Mistral service gracefully
cd "$MISTRAL_DIR"
echo "Stopping Mistral service (timeout: ${SHUTDOWN_TIMEOUT}s)..."
if ! docker-compose stop -t "$SHUTDOWN_TIMEOUT" mistral; then
    echo "Warning: Graceful shutdown failed, forcing stop..."
    if ! docker-compose kill mistral; then
        echo "Error: Failed to stop Mistral service"
        exit 1
    fi
fi

# Wait for container to fully stop
echo "Waiting for container to stop..."
timeout="$SHUTDOWN_TIMEOUT"
while [ $timeout -gt 0 ]; do
    if ! docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null | grep -q "true"; then
        break
    fi
    sleep 1
    ((timeout--))
done

if [ $timeout -eq 0 ]; then
    echo "Warning: Container did not stop within timeout"
fi

echo "Mistral.rs stopped successfully!"