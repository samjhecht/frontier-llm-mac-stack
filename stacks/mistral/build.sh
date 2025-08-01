#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Building Mistral.rs Docker image..."

# Build the Docker image
docker build -t frontier-mistral:latest "$SCRIPT_DIR/docker"

echo "Mistral.rs Docker image built successfully!"