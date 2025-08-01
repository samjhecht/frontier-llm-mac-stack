#!/bin/bash
# Frontier LLM Stack - Mistral.rs Status Script
# 
# This script checks the status and health of the Mistral.rs inference server.
#
# Usage:
#   ./mistral-status.sh

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
CONTAINER_NAME="frontier-mistral"
API_PORT="${MISTRAL_API_PORT:-8080}"

echo "Checking Mistral.rs status..."
echo ""

# Check if container exists
if ! docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    echo "✗ Mistral container does not exist"
    echo "  Run ./mistral-start.sh to start the service"
    exit 1
fi

# Check if container is running
if ! docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null | grep -q "true"; then
    echo "✗ Mistral container is not running"
    echo "  Run ./mistral-start.sh to start the service"
    exit 1
fi

echo "✓ Container is running"

# Check health endpoint
if curl -sf "http://localhost:${API_PORT}/health" >/dev/null 2>&1; then
    echo "✓ Health check passed"
else
    echo "✗ Health check failed"
    echo "  The service may still be starting up"
fi

# Get container info
echo ""
echo "Container Information:"
docker inspect "$CONTAINER_NAME" --format '  Created: {{.Created}}
  Status: {{.State.Status}}
  Uptime: {{.State.StartedAt}}
  Restart Count: {{.RestartCount}}'

# Check resource usage
echo ""
echo "Resource Usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" "$CONTAINER_NAME"

# Check available models
echo ""
echo "Checking available models..."
if response=$(curl -sf "http://localhost:${API_PORT}/v1/models" 2>/dev/null); then
    echo "✓ Models endpoint accessible"
    echo "  Response: $response"
else
    echo "✗ Could not access models endpoint"
fi

# Show recent logs
echo ""
echo "Recent logs (last 10 lines):"
docker logs --tail 10 "$CONTAINER_NAME" 2>&1

echo ""
echo "For full logs run: docker logs -f $CONTAINER_NAME"