#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source common functions
source "$SCRIPT_DIR/build-common.sh"

# Check prerequisites
check_docker || exit 1

# Get platform info
get_platform_info

print_info "Detected platform: $PLATFORM $ARCH"

# Set build parameters based on platform
if [[ "$PLATFORM" == "Darwin" ]]; then
    print_info "Building for macOS with Metal support"
    # Check Metal availability
    check_metal_support || exit 1
    BUILD_FEATURES="metal"
    RUNTIME_BASE="debian:bookworm-slim"
    DOCKERFILE="Dockerfile"
    IMAGE_TAG="frontier-mistral:metal"
else
    print_error "This script is for building Metal-enabled images on macOS"
    print_info "Use build.sh for CUDA builds on Linux"
    exit 1
fi

# Check connectivity
check_github_connectivity || exit 1
check_repository_access || exit 1

# Validate Docker build context
validate_docker_context "$SCRIPT_DIR/docker" || exit 1

print_info "Building Mistral.rs Docker image with Metal support..."

# Load environment variables
load_env_vars "$SCRIPT_DIR"

# Set default versions if not specified
MISTRAL_RS_VERSION=${MISTRAL_RS_VERSION:-v0.5.0}

print_info "Building mistral.rs version: $MISTRAL_RS_VERSION"
print_info "Build features: $BUILD_FEATURES"

# Build the Docker image
if ! docker build \
    --progress=plain \
    --build-arg BUILD_MODE="metal" \
    --build-arg BUILD_FEATURES="$BUILD_FEATURES" \
    --build-arg MISTRAL_RS_VERSION="$MISTRAL_RS_VERSION" \
    --build-arg RUNTIME_BASE="$RUNTIME_BASE" \
    --build-arg USE_V5_MODE="true" \
    --tag "${IMAGE_TAG}-latest" \
    --tag "${IMAGE_TAG}-$(date +%Y%m%d-%H%M%S)" \
    --tag frontier-mistral:latest \
    --file "$SCRIPT_DIR/docker/$DOCKERFILE" \
    "$SCRIPT_DIR/docker"; then
    print_error "Docker build failed"
    exit 1
fi

# Verify the built image
verify_image "${IMAGE_TAG}-latest" || exit 1

print_success "Mistral.rs Docker image with Metal support built successfully!"
print_info "Tagged as: ${IMAGE_TAG}-latest and frontier-mistral:latest"

# Test the server binary
test_server_binary "${IMAGE_TAG}-latest" || exit 1

print_info ""
print_info "To run the server with a model, use:"
print_info "  docker run -v /path/to/models:/models -p 11434:11434 ${IMAGE_TAG}-latest"