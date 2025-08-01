#!/bin/bash
# Script to build mistral.rs locally on Mac and create Docker image

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source common functions
source "$SCRIPT_DIR/build-common.sh"

# Check for required tools
if ! command -v cargo &> /dev/null; then
    print_error "Rust/Cargo is not installed. Please install from https://rustup.rs/"
    exit 1
fi

check_docker || exit 1

# Get platform info and check Metal support
get_platform_info
check_metal_support || exit 1

# Create temporary build directory
BUILD_DIR="${SCRIPT_DIR}/docker/build"
mkdir -p "$BUILD_DIR"

# Clone and build mistral.rs locally
print_info "Cloning mistral.rs..."
cd "$BUILD_DIR"
if [ -d "mistral.rs" ]; then
    print_info "mistral.rs directory exists, updating..."
    cd mistral.rs
    timeout "$DEFAULT_GIT_TIMEOUT" git fetch
    timeout "$DEFAULT_GIT_TIMEOUT" git checkout v0.6.0
else
    clone_repository "https://github.com/EricLBuehler/mistral.rs.git" "mistral.rs" "v0.6.0" || exit 1
    cd mistral.rs
fi

print_info "Building mistral.rs with Metal support..."
cargo build --release --features metal

# Copy the binary
print_info "Copying binary..."
cp target/release/mistralrs-server "$SCRIPT_DIR/docker/"

# Build Docker image
cd "$SCRIPT_DIR"
print_info "Building Docker image..."
docker build \
    --progress=plain \
    --build-arg USE_V5_MODE="true" \
    --tag frontier-mistral:metal-latest \
    --tag frontier-mistral:latest \
    --file docker/Dockerfile.prebuilt \
    docker/

# Clean up
rm -f "$SCRIPT_DIR/docker/mistralrs-server"

# Verify the built image
verify_image "frontier-mistral:metal-latest" || exit 1

print_success "Docker image built successfully!"
print_info "Tagged as: frontier-mistral:metal-latest and frontier-mistral:latest"

# Test the server binary
test_server_binary "frontier-mistral:metal-latest" || exit 1