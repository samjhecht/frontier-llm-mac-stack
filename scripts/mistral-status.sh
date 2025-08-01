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
    # Parse and display models nicely
    if command -v jq >/dev/null 2>&1; then
        model_count=$(echo "$response" | jq '.data | length' 2>/dev/null || echo "0")
        if [ "$model_count" != "0" ]; then
            echo "  Found $model_count model(s):"
            echo "$response" | jq -r '.data[] | "    - \(.id)"' 2>/dev/null || echo "  (unable to parse models)"
        else
            echo "  No models loaded"
            echo "  Use download-model.sh to download models"
        fi
    else
        echo "  Raw response: $response"
    fi
else
    echo "✗ Could not access models endpoint"
fi

# Test basic inference capability
echo ""
echo "Testing inference capability..."
if [ -n "$(curl -sf "http://localhost:${API_PORT}/v1/models" 2>/dev/null | grep -o '"data":\[[^]]*\]' | grep -v '\[\]')" ]; then
    # Models are loaded, try a simple completion
    test_response=$(curl -sf -X POST "http://localhost:${API_PORT}/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d '{
            "messages": [{"role": "user", "content": "Say hello"}],
            "max_tokens": 10,
            "temperature": 0.1
        }' 2>/dev/null || echo "FAILED")
    
    if [ "$test_response" != "FAILED" ] && echo "$test_response" | grep -q "content"; then
        echo "✓ Inference test passed"
    else
        echo "✗ Inference test failed or no model specified"
        echo "  This is normal if no default model is configured"
    fi
else
    echo "  Skipping inference test (no models loaded)"
fi

# Show recent logs
echo ""
echo "Recent logs (last 10 lines):"
docker logs --tail 10 "$CONTAINER_NAME" 2>&1

echo ""
echo "For full logs run: docker logs -f $CONTAINER_NAME"