#!/bin/bash
# Frontier LLM Stack - Mistral.rs Start Script
# 
# This script starts the Mistral.rs inference server with proper configuration
# and ensures it connects to the monitoring infrastructure.
#
# Usage:
#   ./mistral-start.sh
#
# Environment Variables:
#   MISTRAL_API_PORT         - API port (default: 8080)
#   MISTRAL_MODELS_PATH      - Path to models directory
#   MISTRAL_MEMORY_LIMIT     - Memory limit (default: 64G)
#   MISTRAL_LOG_LEVEL        - Log level (default: info)
#
# Prerequisites:
#   - Docker and docker-compose installed
#   - Docker daemon running
#   - frontier-llm-network exists
#   - Models downloaded to models directory

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MISTRAL_DIR="$PROJECT_ROOT/stacks/mistral"

# Configuration
CONTAINER_NAME="frontier-mistral"
NETWORK_NAME="frontier-llm-network"
MONITORING_NETWORK="frontier-monitoring"
API_PORT="${MISTRAL_API_PORT:-8080}"

echo "Starting Mistral.rs inference server..."

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "Error: docker-compose is not installed or not in PATH"
    exit 1
fi

# Create networks if they don't exist (with race condition handling)
for network in "$NETWORK_NAME" "$MONITORING_NETWORK"; do
    if ! docker network inspect "$network" >/dev/null 2>&1; then
        echo "Creating $network..."
        # Try to create the network, but don't fail if it already exists (race condition)
        if ! docker network create "$network" 2>/dev/null; then
            # Check if the network now exists (created by another process)
            if docker network inspect "$network" >/dev/null 2>&1; then
                echo "Network $network already exists (created by another process)"
            else
                echo "Error: Failed to create Docker network $network"
                exit 1
            fi
        fi
    fi
done

# Check if .env file exists
if [ ! -f "$MISTRAL_DIR/.env" ]; then
    if [ -f "$MISTRAL_DIR/.env.example" ]; then
        echo "Creating .env file from .env.example..."
        cp "$MISTRAL_DIR/.env.example" "$MISTRAL_DIR/.env"
        echo "Please review and update $MISTRAL_DIR/.env with your settings"
    else
        echo "Warning: No .env file found"
    fi
fi

# Ensure model directory exists
MODELS_PATH="${MISTRAL_MODELS_PATH:-$MISTRAL_DIR/data/mistral-models}"
if [ ! -d "$MODELS_PATH" ]; then
    echo "Creating models directory at $MODELS_PATH..."
    mkdir -p "$MODELS_PATH"
fi

# Detect platform and select appropriate compose files
COMPOSE_FILES="-f docker-compose.yml"
if [ "$(uname)" = "Darwin" ]; then
    echo "Detected macOS - using Metal acceleration"
elif [ -e /proc/driver/nvidia/version ]; then
    echo "Detected NVIDIA GPU - using CUDA acceleration"
    COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.cuda.yml"
else
    echo "No GPU detected - using CPU mode"
fi

# Start Mistral service
cd "$MISTRAL_DIR"
echo "Starting Mistral service..."
if ! docker-compose $COMPOSE_FILES up -d mistral; then
    echo "Error: Failed to start Mistral service"
    exit 1
fi

# Wait for service to be ready
echo "Waiting for Mistral to be ready..."
max_attempts=30
attempt=1

while [ $attempt -le $max_attempts ]; do
    if curl -sf "http://localhost:${API_PORT}/health" >/dev/null 2>&1; then
        echo "✓ Mistral is healthy"
        break
    fi
    if [ $attempt -eq $max_attempts ]; then
        echo "✗ Mistral health check failed after $max_attempts attempts"
        echo "Check logs with: docker logs $CONTAINER_NAME"
        exit 1
    fi
    echo "  Waiting for Mistral... (attempt $attempt/$max_attempts)"
    sleep 2
    ((attempt++))
done

echo ""
echo "Mistral.rs started successfully!"
echo ""
echo "Access points:"
echo "  - API: http://localhost:${API_PORT}"
echo "  - Health: http://localhost:${API_PORT}/health"
echo "  - Models: http://localhost:${API_PORT}/v1/models"
echo ""
echo "To check status: docker ps -f name=$CONTAINER_NAME"
echo "To view logs: docker logs -f $CONTAINER_NAME"
echo "To stop: ./mistral-stop.sh"