#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Starting Frontier LLM monitoring stack..."

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "Error: docker-compose is not installed or not in PATH"
    echo "Please install docker-compose to continue"
    exit 1
fi

# Create network if it doesn't exist
if ! docker network inspect frontier-llm-network >/dev/null 2>&1; then
    echo "Creating frontier-llm-network..."
    docker network create frontier-llm-network
fi

# Start monitoring services only
cd "$PROJECT_ROOT"

# Check if GPU profile should be enabled
GPU_PROFILE=""
if command -v nvidia-smi &> /dev/null && nvidia-smi >/dev/null 2>&1; then
    echo "GPU detected, enabling GPU monitoring..."
    GPU_PROFILE="--profile gpu"
fi

echo "Starting monitoring services..."
if [ -n "$GPU_PROFILE" ]; then
    docker-compose \
        -f stacks/common/base/docker-compose.yml \
        -f stacks/common/monitoring/docker-compose.yml \
        $GPU_PROFILE \
        up -d prometheus grafana node-exporter nvidia-exporter
else
    docker-compose \
        -f stacks/common/base/docker-compose.yml \
        -f stacks/common/monitoring/docker-compose.yml \
        up -d prometheus grafana node-exporter
fi

# Wait for services to be healthy
echo "Waiting for services to be ready..."
sleep 5

# Check service health
SERVICES=("prometheus" "grafana" "node-exporter")
if [ -n "$GPU_PROFILE" ]; then
    SERVICES+=("nvidia-exporter")
fi

ALL_HEALTHY=true
for service in "${SERVICES[@]}"; do
    container_name="frontier-${service}"
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "^${container_name}.*Up"; then
        echo "✓ ${service} is running"
    else
        echo "✗ ${service} failed to start"
        ALL_HEALTHY=false
    fi
done

if [ "$ALL_HEALTHY" = true ]; then
    echo ""
    echo "Monitoring stack started successfully!"
    echo ""
    echo "Access points:"
    echo "  - Prometheus: http://localhost:9090"
    echo "  - Grafana: http://localhost:3000 (admin/changeme)"
    echo "  - Node Exporter: http://localhost:9100/metrics"
    if [ -n "$GPU_PROFILE" ]; then
        echo "  - NVIDIA GPU Exporter: http://localhost:9400/metrics"
    fi
    echo ""
    echo "To check status: docker-compose -f stacks/common/monitoring/docker-compose.yml ps"
    echo "To view logs: docker-compose -f stacks/common/monitoring/docker-compose.yml logs -f"
else
    echo ""
    echo "Some services failed to start. Check logs with:"
    echo "docker-compose -f stacks/common/monitoring/docker-compose.yml logs"
    exit 1
fi