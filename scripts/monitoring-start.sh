#!/bin/bash
# Frontier LLM Monitoring Stack - Start Script
# 
# This script starts the monitoring components (Prometheus, Grafana, Node Exporter, and optionally NVIDIA GPU Exporter)
# independently of the inference engines (Ollama/Mistral).
#
# Usage:
#   ./monitoring-start.sh
#
# Environment Variables:
#   FRONTIER_CONTAINER_PREFIX    - Container name prefix (default: "frontier-")
#   FRONTIER_NETWORK_NAME        - Docker network name (default: "frontier-llm-network")
#   FRONTIER_PROMETHEUS_PORT     - Prometheus port (default: 9090)
#   FRONTIER_GRAFANA_PORT        - Grafana port (default: 3000)
#   FRONTIER_NODE_EXPORTER_PORT  - Node exporter port (default: 9100)
#   FRONTIER_NVIDIA_EXPORTER_PORT - NVIDIA GPU exporter port (default: 9400)
#   FRONTIER_DATA_VOLUME_PATH    - Custom data volume path (optional)
#
# Prerequisites:
#   - Docker and docker-compose installed
#   - Docker daemon running
#   - For GPU monitoring: NVIDIA GPU with nvidia-docker runtime
#
# Common Issues:
#   - Port conflicts: Check if ports are already in use
#   - Network issues: Ensure frontier-llm-network exists or can be created
#   - GPU monitoring: Requires nvidia-docker runtime and NVIDIA GPU

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration variables with environment variable support
CONTAINER_PREFIX="${FRONTIER_CONTAINER_PREFIX:-frontier-}"
NETWORK_NAME="${FRONTIER_NETWORK_NAME:-frontier-llm-network}"
PROMETHEUS_PORT="${FRONTIER_PROMETHEUS_PORT:-9090}"
GRAFANA_PORT="${FRONTIER_GRAFANA_PORT:-3000}"
NODE_EXPORTER_PORT="${FRONTIER_NODE_EXPORTER_PORT:-9100}"
NVIDIA_EXPORTER_PORT="${FRONTIER_NVIDIA_EXPORTER_PORT:-9400}"
DATA_VOLUME_PATH="${FRONTIER_DATA_VOLUME_PATH:-}"

echo "Starting Frontier LLM monitoring stack..."

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "Error: docker-compose is not installed or not in PATH"
    echo "Please install docker-compose to continue"
    exit 1
fi

# Create network if it doesn't exist
if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    echo "Creating $NETWORK_NAME..."
    if ! docker network create "$NETWORK_NAME"; then
        echo "Error: Failed to create Docker network $NETWORK_NAME"
        exit 1
    fi
fi

# Validate Prometheus configuration
PROMETHEUS_CONFIG="stacks/common/monitoring/config/prometheus/prometheus.yml"
if [ -f "$PROMETHEUS_CONFIG" ]; then
    echo "Validating Prometheus configuration..."
    if docker run --rm -v "$PROJECT_ROOT/$PROMETHEUS_CONFIG:/etc/prometheus/prometheus.yml:ro" prom/prometheus:latest promtool check config /etc/prometheus/prometheus.yml 2>&1 | grep -q "SUCCESS"; then
        echo "✓ Prometheus configuration is valid"
    else
        echo "✗ Invalid Prometheus configuration detected"
        echo "Run the following command to see details:"
        echo "docker run --rm -v \"$PROJECT_ROOT/$PROMETHEUS_CONFIG:/etc/prometheus/prometheus.yml:ro\" prom/prometheus:latest promtool check config /etc/prometheus/prometheus.yml"
        exit 1
    fi
else
    echo "Warning: Prometheus configuration file not found at $PROMETHEUS_CONFIG"
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
    if ! docker-compose \
        -f stacks/common/base/docker-compose.yml \
        -f stacks/common/monitoring/docker-compose.yml \
        $GPU_PROFILE \
        up -d prometheus grafana node-exporter nvidia-exporter; then
        echo "Error: Failed to start monitoring services with GPU profile"
        exit 1
    fi
else
    if ! docker-compose \
        -f stacks/common/base/docker-compose.yml \
        -f stacks/common/monitoring/docker-compose.yml \
        up -d prometheus grafana node-exporter; then
        echo "Error: Failed to start monitoring services"
        exit 1
    fi
fi

# Wait for services to be healthy
echo "Waiting for services to be ready..."
sleep 5

# Check service health with HTTP endpoints where possible
check_http_health() {
    local service_name=$1
    local url=$2
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -sf "$url" >/dev/null 2>&1; then
            echo "✓ ${service_name} is healthy (HTTP check passed)"
            return 0
        fi
        if [ $attempt -eq $max_attempts ]; then
            echo "✗ ${service_name} health check failed after $max_attempts attempts"
            return 1
        fi
        echo "  Waiting for ${service_name} to be ready... (attempt $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
}

# Check service health
SERVICES=("prometheus" "grafana" "node-exporter")
SERVICE_URLS=(
    "http://localhost:${PROMETHEUS_PORT}/-/healthy"
    "http://localhost:${GRAFANA_PORT}/api/health"
    "http://localhost:${NODE_EXPORTER_PORT}/metrics"
)

if [ -n "$GPU_PROFILE" ]; then
    SERVICES+=("nvidia-exporter")
    SERVICE_URLS+=("http://localhost:${NVIDIA_EXPORTER_PORT}/metrics")
fi

ALL_HEALTHY=true
for i in "${!SERVICES[@]}"; do
    service="${SERVICES[$i]}"
    url="${SERVICE_URLS[$i]}"
    container_name="${CONTAINER_PREFIX}${service}"
    
    # First check if container is running
    if ! docker inspect -f '{{.State.Running}}' "$container_name" 2>/dev/null | grep -q "true"; then
        echo "✗ ${service} container is not running"
        ALL_HEALTHY=false
        continue
    fi
    
    # Then check HTTP health endpoint if available
    if [ -n "$url" ]; then
        if ! check_http_health "$service" "$url"; then
            ALL_HEALTHY=false
        fi
    else
        echo "✓ ${service} is running (container check)"
    fi
done

if [ "$ALL_HEALTHY" = true ]; then
    echo ""
    echo "Monitoring stack started successfully!"
    echo ""
    echo "Access points:"
    echo "  - Prometheus: http://localhost:${PROMETHEUS_PORT}"
    echo "  - Grafana: http://localhost:${GRAFANA_PORT}"
    echo "    Default credentials: admin/changeme"
    echo "    ⚠️  SECURITY WARNING: Please change the default password on first login!"
    echo "  - Node Exporter: http://localhost:${NODE_EXPORTER_PORT}/metrics"
    if [ -n "$GPU_PROFILE" ]; then
        echo "  - NVIDIA GPU Exporter: http://localhost:${NVIDIA_EXPORTER_PORT}/metrics"
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