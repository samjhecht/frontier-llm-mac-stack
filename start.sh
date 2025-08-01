#!/bin/bash

# Frontier LLM Stack - Start Script

set -e

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "Error: docker-compose is not installed or not in PATH"
    echo "Please install docker-compose to continue"
    exit 1
fi

# Check if a stack is selected
if [ ! -f ".current-stack" ]; then
    echo "Error: No stack selected. Please run './stack-select.sh select <stack>' first."
    exit 1
fi

# Check if docker-compose-wrapper.sh is executable
if [ ! -x "./docker-compose-wrapper.sh" ]; then
    echo "Error: docker-compose-wrapper.sh is not executable"
    echo "Run: chmod +x docker-compose-wrapper.sh"
    exit 1
fi

CURRENT_STACK=$(cat .current-stack)
echo "Starting Frontier LLM Stack with ${CURRENT_STACK} stack..."

# Validate environment variables
if [ -x "./scripts/validate-env.sh" ]; then
    ./scripts/validate-env.sh
    echo ""
fi

# Start the services using the wrapper (network will be created automatically)
./docker-compose-wrapper.sh up -d

# Wait for services to be healthy
echo "Waiting for services to be healthy..."

# Function to check if a service is healthy
check_service_health() {
    local service=$1
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if ./docker-compose-wrapper.sh ps | grep -q "${service}.*healthy"; then
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    return 1
}

# Check health of critical services
CRITICAL_SERVICES=("${CURRENT_STACK}" "prometheus" "grafana")

for service in "${CRITICAL_SERVICES[@]}"; do
    echo -n "Checking ${service}... "
    if check_service_health "$service"; then
        echo "healthy"
    else
        echo "not healthy (timeout)"
        echo "Warning: Service ${service} is not healthy yet"
    fi
done

# Show status
./docker-compose-wrapper.sh ps

echo ""
echo "Stack started successfully!"
echo "Access points:"
echo "  - ${CURRENT_STACK^} API: http://localhost:11434"
echo "  - Grafana: http://localhost:3000 (check .env for credentials)"
echo "  - Prometheus: http://localhost:9090"