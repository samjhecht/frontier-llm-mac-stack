#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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

# Check for Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not in PATH"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info >/dev/null 2>&1; then
    print_error "Docker daemon is not running"
    exit 1
fi

# Detect platform
PLATFORM=$(uname -s)
ARCH=$(uname -m)

print_info "Detected platform: $PLATFORM $ARCH"

# Set build parameters based on platform
if [[ "$PLATFORM" == "Darwin" ]]; then
    print_info "Building for macOS with Metal support"
    BUILD_FEATURES="metal"
    RUNTIME_BASE="debian:bookworm-slim"
    DOCKERFILE="Dockerfile.metal"
    IMAGE_TAG="frontier-mistral:metal"
else
    print_error "This script is for building Metal-enabled images on macOS"
    print_info "Use build.sh for CUDA builds on Linux"
    exit 1
fi

# Test GitHub connectivity (for cloning mistral.rs)
print_info "Checking GitHub connectivity..."
if ! curl -s --head https://github.com >/dev/null; then
    print_error "Cannot reach GitHub. Please check your internet connection"
    exit 1
fi

# Check if mistral.rs repository is accessible
print_info "Verifying mistral.rs repository accessibility..."
if ! git ls-remote https://github.com/EricLBuehler/mistral.rs.git HEAD >/dev/null 2>&1; then
    print_error "Cannot access mistral.rs repository"
    exit 1
fi

print_info "Building Mistral.rs Docker image with Metal support..."

# Load environment variables if .env exists
if [ -f "$SCRIPT_DIR/../.env" ]; then
    source "$SCRIPT_DIR/../.env"
elif [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
fi

# Set default versions if not specified
MISTRAL_RS_VERSION=${MISTRAL_RS_VERSION:-v0.5.0}

print_info "Building mistral.rs version: $MISTRAL_RS_VERSION"
print_info "Build features: $BUILD_FEATURES"

# Build the Docker image
if ! docker build \
    --progress=plain \
    --build-arg MISTRAL_RS_VERSION="$MISTRAL_RS_VERSION" \
    --build-arg BUILD_FEATURES="$BUILD_FEATURES" \
    --build-arg RUNTIME_BASE="$RUNTIME_BASE" \
    --tag "${IMAGE_TAG}-latest" \
    --tag "${IMAGE_TAG}-$(date +%Y%m%d-%H%M%S)" \
    --tag frontier-mistral:latest \
    --file "$SCRIPT_DIR/docker/$DOCKERFILE" \
    "$SCRIPT_DIR/docker"; then
    print_error "Docker build failed"
    exit 1
fi

# Verify the built image
print_info "Verifying built image..."
if ! docker image inspect "${IMAGE_TAG}-latest" >/dev/null 2>&1; then
    print_error "Built image not found"
    exit 1
fi

# Check if the mistralrs-server binary exists in the image
print_info "Verifying mistralrs-server binary in image..."
if ! docker run --rm --entrypoint=ls "${IMAGE_TAG}-latest" /usr/local/bin/mistralrs-server >/dev/null 2>&1; then
    print_error "mistralrs-server binary not found in image"
    exit 1
fi

# Get image size
IMAGE_SIZE=$(docker image inspect "${IMAGE_TAG}-latest" --format='{{.Size}}' | numfmt --to=iec-i --suffix=B 2>/dev/null || echo "Unknown")
print_info "Image size: $IMAGE_SIZE"

print_success "Mistral.rs Docker image with Metal support built successfully!"
print_info "Tagged as: ${IMAGE_TAG}-latest and frontier-mistral:latest"

# Optional: Test the server can start (will fail without models, but checks binary works)
print_info "Testing server binary..."
if docker run --rm --entrypoint=mistralrs-server "${IMAGE_TAG}-latest" --help >/dev/null 2>&1; then
    print_success "Server binary is functional"
else
    print_error "Server binary test failed"
    exit 1
fi

print_info ""
print_info "To run the server with a model, use:"
print_info "  docker run -v /path/to/models:/models -p 11434:11434 ${IMAGE_TAG}-latest"