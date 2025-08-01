#!/bin/bash
# Script to build mistral.rs locally on Mac and create Docker image

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

# Check for required tools
if ! command -v cargo &> /dev/null; then
    print_error "Rust/Cargo is not installed. Please install from https://rustup.rs/"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not in PATH"
    exit 1
fi

# Create temporary build directory
BUILD_DIR="${SCRIPT_DIR}/docker/build"
mkdir -p "$BUILD_DIR"

# Clone and build mistral.rs locally
print_info "Cloning mistral.rs..."
cd "$BUILD_DIR"
if [ -d "mistral.rs" ]; then
    print_info "mistral.rs directory exists, updating..."
    cd mistral.rs
    git fetch
    git checkout v0.6.0
else
    git clone --depth 1 --branch v0.6.0 https://github.com/EricLBuehler/mistral.rs.git
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
    --tag frontier-mistral:metal-latest \
    --tag frontier-mistral:latest \
    --file docker/Dockerfile.metal.prebuilt \
    docker/

# Clean up
rm -f "$SCRIPT_DIR/docker/mistralrs-server"

print_success "Docker image built successfully!"
print_info "Tagged as: frontier-mistral:metal-latest and frontier-mistral:latest"