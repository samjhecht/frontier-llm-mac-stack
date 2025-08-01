#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source common functions
source "$SCRIPT_DIR/build-common.sh"

# Check prerequisites
check_docker || exit 1
check_nvidia_runtime || exit 1
check_github_connectivity || exit 1
check_repository_access || exit 1

# Validate Docker build context
validate_docker_context "$SCRIPT_DIR/docker" || exit 1

print_info "Building Mistral.rs Docker image..."

# Load environment variables
load_env_vars "$SCRIPT_DIR"

# Set default versions if not specified
CUDA_VERSION=${CUDA_VERSION:-$DEFAULT_CUDA_VERSION}
MISTRAL_RS_VERSION=${MISTRAL_RS_VERSION:-$DEFAULT_MISTRAL_RS_VERSION}
RUNTIME_BASE=${RUNTIME_BASE:-nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu22.04}

print_info "Building with CUDA version: $CUDA_VERSION"
print_info "Building mistral.rs version: $MISTRAL_RS_VERSION"

# Build the Docker image with build args for better caching
if ! docker build \
    --progress=plain \
    --build-arg BUILD_MODE="cuda" \
    --build-arg BUILD_FEATURES="cuda" \
    --build-arg MISTRAL_RS_VERSION="$MISTRAL_RS_VERSION" \
    --build-arg RUNTIME_BASE="$RUNTIME_BASE" \
    --build-arg USE_V5_MODE="false" \
    --tag frontier-mistral:latest \
    --tag frontier-mistral:$(date +%Y%m%d-%H%M%S) \
    "$SCRIPT_DIR/docker"; then
    print_error "Docker build failed"
    exit 1
fi

# Verify the built image
verify_image "frontier-mistral:latest" || exit 1

print_success "Mistral.rs Docker image built successfully!"
print_info "Tagged as: frontier-mistral:latest"

# Test the server binary
test_server_binary "frontier-mistral:latest" || exit 1