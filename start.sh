#!/bin/bash

# Frontier LLM Stack - Start Script

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
print_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

print_info() {
    echo -e "${YELLOW}INFO: $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    print_error "docker-compose is not installed or not in PATH"
    print_info "Please install docker-compose to continue"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info >/dev/null 2>&1; then
    print_error "Docker daemon is not running"
    print_info "Please start Docker Desktop and try again"
    exit 1
fi

# Check if a stack is selected
if [ ! -f ".current-stack" ]; then
    print_error "No stack selected. Please run './stack-select.sh select <stack>' first."
    exit 1
fi

# Check if docker-compose-wrapper.sh is executable
if [ ! -x "./docker-compose-wrapper.sh" ]; then
    print_error "docker-compose-wrapper.sh is not executable"
    print_info "Run: chmod +x docker-compose-wrapper.sh"
    exit 1
fi

CURRENT_STACK=$(cat .current-stack)
print_info "Starting Frontier LLM Stack with ${CURRENT_STACK} stack..."

# Validate environment variables
if [ -x "./scripts/validate-env.sh" ]; then
    ./scripts/validate-env.sh
    echo ""
fi

# For Mistral stack, check if the image needs to be built
if [ "${CURRENT_STACK}" = "mistral" ]; then
    if ! docker image inspect frontier-mistral:latest >/dev/null 2>&1; then
        print_info "Mistral Docker image not found. Building it now..."
        if [ -x "./stacks/mistral/build.sh" ]; then
            if ./stacks/mistral/build.sh; then
                print_success "Mistral image built successfully"
            else
                print_error "Failed to build Mistral image"
                exit 1
            fi
        else
            print_error "Mistral build script not found or not executable"
            exit 1
        fi
    fi
fi

# Ensure the network exists
NETWORK_NAME="frontier-llm-network"
if ! docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
    print_info "Creating Docker network: ${NETWORK_NAME}"
    if ! docker network create "${NETWORK_NAME}"; then
        print_error "Failed to create Docker network"
        exit 1
    fi
fi

# Start the services using the wrapper
print_info "Starting services..."
if ./docker-compose-wrapper.sh up -d; then
    print_success "Services started"
else
    EXIT_CODE=$?
    print_error "Failed to start services (exit code: $EXIT_CODE)"
    print_info "Check logs with: ./docker-compose-wrapper.sh logs"
    exit $EXIT_CODE
fi

# Wait for services to be healthy
print_info "Waiting for services to be healthy..."

# Function to check if a service is healthy
check_service_health() {
    local service=$1
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if ./docker-compose-wrapper.sh ps 2>/dev/null | grep -q "${service}.*healthy"; then
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
        echo -e "${GREEN}healthy${NC}"
    else
        echo -e "${YELLOW}not healthy (timeout)${NC}"
        print_warning "Service ${service} is not healthy yet"
    fi
done

# Show status
print_info "Service Status:"
./docker-compose-wrapper.sh ps

echo ""
print_success "Stack started successfully!"
print_info "Access points:"
echo "  - ${CURRENT_STACK^} API: http://localhost:11434"
echo "  - Grafana: http://localhost:3000 (check .env for credentials)"
echo "  - Prometheus: http://localhost:9090"