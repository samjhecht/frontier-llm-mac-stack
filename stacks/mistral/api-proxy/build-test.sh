#!/usr/bin/env bash
set -euo pipefail

echo "Testing Mistral-Ollama API proxy build..."
echo "========================================"

# Build the Docker image
echo "Building Docker image..."
docker build -t test-mistral-ollama-proxy:latest .

echo ""
echo "Build completed successfully!"
echo ""
echo "To run the proxy locally:"
echo "  docker run -p 11434:11434 -e MISTRAL_URL=http://host.docker.internal:8080 test-mistral-ollama-proxy:latest"