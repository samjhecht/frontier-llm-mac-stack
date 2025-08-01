#!/bin/bash

# Frontier LLM Stack - Stop Script

set -e

# Check if a stack is selected
if [ ! -f ".current-stack" ]; then
    echo "Error: No stack selected. Please run './stack-select.sh select <stack>' first."
    exit 1
fi

CURRENT_STACK=$(cat .current-stack)
echo "Stopping Frontier LLM Stack with ${CURRENT_STACK} stack..."

# Stop the services using the wrapper
./docker-compose-wrapper.sh down

echo "Stack stopped successfully!"