#!/bin/bash

# Frontier LLM Stack - Start Script

set -e

# Check if a stack is selected
if [ ! -f ".current-stack" ]; then
    echo "Error: No stack selected. Please run './stack-select.sh select <stack>' first."
    exit 1
fi

CURRENT_STACK=$(cat .current-stack)
echo "Starting Frontier LLM Stack with ${CURRENT_STACK} stack..."

# Create the network if it doesn't exist
docker network create frontier-llm-network 2>/dev/null || true

# Start the services using the wrapper
./docker-compose-wrapper.sh up -d

# Wait for services to be healthy
echo "Waiting for services to be healthy..."
sleep 5

# Show status
./docker-compose-wrapper.sh ps

echo ""
echo "Stack started successfully!"
echo "Access points:"
echo "  - ${CURRENT_STACK^} API: http://localhost:11434"
echo "  - Grafana: http://localhost:3000 (admin/frontier-llm)"
echo "  - Prometheus: http://localhost:9090"