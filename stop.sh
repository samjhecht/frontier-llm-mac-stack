#!/bin/bash

# Frontier LLM Stack - Stop Script

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

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    print_error "docker-compose is not installed or not in PATH"
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

# Read current stack
CURRENT_STACK=$(cat .current-stack)
print_info "Stopping Frontier LLM Stack with ${CURRENT_STACK} stack..."

# Check if any services are running
if ! ./docker-compose-wrapper.sh ps --quiet 2>/dev/null | grep -q .; then
    print_info "No services are currently running"
    exit 0
fi

# Stop the services using the wrapper
if ./docker-compose-wrapper.sh down; then
    print_success "Stack stopped successfully!"
else
    EXIT_CODE=$?
    print_error "Failed to stop stack (exit code: $EXIT_CODE)"
    print_info "You can force stop with: docker-compose -f <compose-files> down -v"
    exit $EXIT_CODE
fi