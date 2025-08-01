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

# Stop Mistral service
cd "$MISTRAL_DIR"
echo "Stopping Mistral service..."
if ! docker-compose stop mistral; then
    echo "Error: Failed to stop Mistral service"
    exit 1
fi

echo "Mistral.rs stopped successfully!"