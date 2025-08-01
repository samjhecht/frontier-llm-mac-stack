#!/bin/bash
# Wrapper script to run docker-compose with all required files

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ ! -f "${SCRIPT_DIR}/.current-stack" ]; then
    echo "Error: No stack selected. Please run './stack-select.sh select <stack>' first."
    exit 1
fi

CURRENT_STACK=$(cat "${SCRIPT_DIR}/.current-stack")

exec docker-compose \
    -f "${SCRIPT_DIR}/stacks/${CURRENT_STACK}/docker-compose.yml" \
    -f "${SCRIPT_DIR}/stacks/common/monitoring/docker-compose.yml" \
    -f "${SCRIPT_DIR}/stacks/common/nginx/docker-compose.yml" \
    "$@"
