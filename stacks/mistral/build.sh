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

# Check for NVIDIA Docker runtime (required for CUDA)
if ! docker info 2>/dev/null | grep -q nvidia; then
    print_error "NVIDIA Docker runtime not found. Please install nvidia-docker2"
    print_info "See: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
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

print_info "Building Mistral.rs Docker image..."

# Load environment variables if .env exists
if [ -f "$SCRIPT_DIR/../.env" ]; then
    source "$SCRIPT_DIR/../.env"
elif [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
fi

# Set default versions if not specified
CUDA_VERSION=${CUDA_VERSION:-12.2.0}
MISTRAL_RS_VERSION=${MISTRAL_RS_VERSION:-v0.6.0}

print_info "Building with CUDA version: $CUDA_VERSION"
print_info "Building mistral.rs version: $MISTRAL_RS_VERSION"

# Build the Docker image with build args for better caching
if ! docker build \
    --progress=plain \
    --build-arg CUDA_VERSION="$CUDA_VERSION" \
    --build-arg MISTRAL_RS_VERSION="$MISTRAL_RS_VERSION" \
    --tag frontier-mistral:latest \
    --tag frontier-mistral:$(date +%Y%m%d-%H%M%S) \
    "$SCRIPT_DIR/docker"; then
    print_error "Docker build failed"
    exit 1
fi

# Verify the built image
print_info "Verifying built image..."
if ! docker image inspect frontier-mistral:latest >/dev/null 2>&1; then
    print_error "Built image not found"
    exit 1
fi

# Check if the mistralrs-server binary exists in the image
print_info "Verifying mistralrs-server binary in image..."
if ! docker run --rm frontier-mistral:latest which mistralrs-server >/dev/null 2>&1; then
    print_error "mistralrs-server binary not found in image"
    exit 1
fi

# Get image size
IMAGE_SIZE=$(docker image inspect frontier-mistral:latest --format='{{.Size}}' | numfmt --to=iec-i --suffix=B)
print_info "Image size: $IMAGE_SIZE"

print_success "Mistral.rs Docker image built successfully!"
print_info "Tagged as: frontier-mistral:latest"

# Optional: Test the server can start (will fail without models, but checks binary works)
print_info "Testing server binary (expecting model error)..."
if docker run --rm frontier-mistral:latest mistralrs-server --help >/dev/null 2>&1; then
    print_success "Server binary is functional"
else
    print_error "Server binary test failed"
    exit 1
fi