#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Stopping Frontier LLM monitoring stack..."

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "Error: docker-compose is not installed or not in PATH"
    echo "Please install docker-compose to continue"
    exit 1
fi

cd "$PROJECT_ROOT"

# Check if GPU profile should be enabled for proper cleanup
GPU_PROFILE=""
if docker ps --format "{{.Names}}" | grep -q "frontier-nvidia-exporter"; then
    GPU_PROFILE="--profile gpu"
fi

# Stop monitoring services
echo "Stopping monitoring services..."
if [ -n "$GPU_PROFILE" ]; then
    docker-compose \
        -f stacks/common/base/docker-compose.yml \
        -f stacks/common/monitoring/docker-compose.yml \
        $GPU_PROFILE \
        stop prometheus grafana node-exporter nvidia-exporter
else
    docker-compose \
        -f stacks/common/base/docker-compose.yml \
        -f stacks/common/monitoring/docker-compose.yml \
        stop prometheus grafana node-exporter
fi

# Remove containers (but keep volumes)
echo "Removing monitoring containers..."
if [ -n "$GPU_PROFILE" ]; then
    docker-compose \
        -f stacks/common/base/docker-compose.yml \
        -f stacks/common/monitoring/docker-compose.yml \
        $GPU_PROFILE \
        rm -f prometheus grafana node-exporter nvidia-exporter
else
    docker-compose \
        -f stacks/common/base/docker-compose.yml \
        -f stacks/common/monitoring/docker-compose.yml \
        rm -f prometheus grafana node-exporter
fi

echo ""
echo "Monitoring stack stopped successfully!"
echo ""
echo "Note: Data volumes are preserved. To remove them, run:"
echo "  docker volume rm frontier-llm-mac-stack_prometheus-data"
echo "  docker volume rm frontier-llm-mac-stack_grafana-data"