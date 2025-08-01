#!/bin/bash
# Frontier LLM Monitoring Stack - Stop Script
# 
# This script stops the monitoring components (Prometheus, Grafana, Node Exporter, and optionally NVIDIA GPU Exporter).
#
# Usage:
#   ./monitoring-stop.sh
#
# Environment Variables:
#   FRONTIER_CONTAINER_PREFIX - Container name prefix (default: "frontier-")
#
# Notes:
#   - Data volumes are preserved after stopping
#   - Use docker volume rm to remove data volumes if needed
#
# Prerequisites:
#   - Docker and docker-compose installed
#   - Docker daemon running

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration variables with environment variable support
CONTAINER_PREFIX="${FRONTIER_CONTAINER_PREFIX:-frontier-}"

echo "Stopping Frontier LLM monitoring stack..."

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "Error: docker-compose is not installed or not in PATH"
    echo "Please install docker-compose to continue"
    exit 1
fi

cd "$PROJECT_ROOT"

# Check if any monitoring services are running
MONITORING_SERVICES=("prometheus" "grafana" "node-exporter" "nvidia-exporter")
SERVICES_RUNNING=false

for service in "${MONITORING_SERVICES[@]}"; do
    container_name="${CONTAINER_PREFIX}${service}"
    if docker inspect -f '{{.State.Running}}' "$container_name" 2>/dev/null | grep -q "true"; then
        SERVICES_RUNNING=true
        break
    fi
done

if [ "$SERVICES_RUNNING" = false ]; then
    echo "No monitoring services are currently running."
    exit 0
fi

# Check if GPU profile should be enabled for proper cleanup
GPU_PROFILE=""
if docker ps --format "{{.Names}}" | grep -q "${CONTAINER_PREFIX}nvidia-exporter"; then
    GPU_PROFILE="--profile gpu"
fi

# Stop and remove monitoring services using down command
echo "Stopping and removing monitoring containers..."
if [ -n "$GPU_PROFILE" ]; then
    if ! docker-compose \
        -f stacks/common/base/docker-compose.yml \
        -f stacks/common/monitoring/docker-compose.yml \
        $GPU_PROFILE \
        down --remove-orphans; then
        echo "Error: Failed to stop monitoring services"
        exit 1
    fi
else
    if ! docker-compose \
        -f stacks/common/base/docker-compose.yml \
        -f stacks/common/monitoring/docker-compose.yml \
        down --remove-orphans; then
        echo "Error: Failed to stop monitoring services"
        exit 1
    fi
fi

echo ""
echo "Monitoring stack stopped successfully!"
echo ""
echo "Note: Data volumes are preserved. To remove them, run:"
echo "  docker volume rm frontier-llm-mac-stack_prometheus-data"
echo "  docker volume rm frontier-llm-mac-stack_grafana-data"