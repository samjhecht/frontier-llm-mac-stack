#!/bin/bash
# Wrapper script to run docker-compose with all required files

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "Error: docker-compose is not installed or not in PATH"
    echo "Please install docker-compose to continue"
    exit 1
fi

if [ ! -f "${SCRIPT_DIR}/.current-stack" ]; then
    echo "Error: No stack selected. Please run './stack-select.sh select <stack>' first."
    exit 1
fi

CURRENT_STACK=$(cat "${SCRIPT_DIR}/.current-stack")

# Execute docker-compose with error handling
docker-compose \
    -f "${SCRIPT_DIR}/stacks/common/base/docker-compose.yml" \
    -f "${SCRIPT_DIR}/stacks/${CURRENT_STACK}/docker-compose.yml" \
    -f "${SCRIPT_DIR}/stacks/common/monitoring/docker-compose.yml" \
    -f "${SCRIPT_DIR}/stacks/common/nginx/docker-compose.yml" \
    "$@"

# Capture exit code
EXIT_CODE=$?

# Handle errors
if [ $EXIT_CODE -ne 0 ]; then
    echo "Error: docker-compose command failed with exit code $EXIT_CODE"
    exit $EXIT_CODE
fi
