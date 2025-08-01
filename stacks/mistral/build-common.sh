#!/bin/bash
# Common functions for mistral build scripts

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Configuration defaults
readonly DEFAULT_MISTRAL_RS_VERSION="v0.6.0"
readonly DEFAULT_CUDA_VERSION="12.2.0"
readonly DEFAULT_GIT_TIMEOUT="30"
readonly DEFAULT_HEALTHCHECK_INTERVAL="30s"
readonly DEFAULT_HEALTHCHECK_TIMEOUT="10s"
readonly DEFAULT_HEALTHCHECK_RETRIES="3"

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
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        return 1
    fi

    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon is not running"
        return 1
    fi
    
    return 0
}

# Check for NVIDIA Docker runtime
check_nvidia_runtime() {
    if ! docker info 2>/dev/null | grep -q nvidia; then
        print_error "NVIDIA Docker runtime not found. Please install nvidia-docker2"
        print_info "See: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
        return 1
    fi
    return 0
}

# Check GitHub connectivity with timeout
check_github_connectivity() {
    print_info "Checking GitHub connectivity..."
    if ! timeout "$DEFAULT_GIT_TIMEOUT" curl -s --head https://github.com >/dev/null; then
        print_error "Cannot reach GitHub. Please check your internet connection"
        return 1
    fi
    return 0
}

# Check repository accessibility with timeout
check_repository_access() {
    local repo_url="${1:-https://github.com/EricLBuehler/mistral.rs.git}"
    
    print_info "Verifying repository accessibility..."
    if ! timeout "$DEFAULT_GIT_TIMEOUT" git ls-remote "$repo_url" HEAD >/dev/null 2>&1; then
        print_error "Cannot access repository: $repo_url"
        return 1
    fi
    return 0
}

# Validate Docker build context
validate_docker_context() {
    local context_dir="$1"
    
    if [ ! -d "$context_dir" ]; then
        print_error "Docker build context does not exist: $context_dir"
        return 1
    fi
    
    if [ ! -f "$context_dir/Dockerfile" ] && [ ! -f "$context_dir/Dockerfile.prebuilt" ]; then
        print_error "No Dockerfile found in context: $context_dir"
        return 1
    fi
    
    if [ ! -f "$context_dir/docker-entrypoint-unified.sh" ]; then
        print_error "Missing docker-entrypoint-unified.sh in context: $context_dir"
        return 1
    fi
    
    return 0
}

# Load environment variables
load_env_vars() {
    local script_dir="$1"
    
    if [ -f "$script_dir/../.env" ]; then
        source "$script_dir/../.env"
    elif [ -f "$script_dir/.env" ]; then
        source "$script_dir/.env"
    fi
}

# Verify built image
verify_image() {
    local image_name="$1"
    
    print_info "Verifying built image..."
    if ! docker image inspect "$image_name" >/dev/null 2>&1; then
        print_error "Built image not found: $image_name"
        return 1
    fi
    
    # Check if the mistralrs-server binary exists in the image
    print_info "Verifying mistralrs-server binary in image..."
    if ! docker run --rm --entrypoint=which "$image_name" mistralrs-server >/dev/null 2>&1; then
        print_error "mistralrs-server binary not found in image"
        return 1
    fi
    
    # Get image size
    local image_size
    image_size=$(docker image inspect "$image_name" --format='{{.Size}}' | numfmt --to=iec-i --suffix=B 2>/dev/null || echo "Unknown")
    print_info "Image size: $image_size"
    
    return 0
}

# Test server binary
test_server_binary() {
    local image_name="$1"
    
    print_info "Testing server binary..."
    if docker run --rm --entrypoint=mistralrs-server "$image_name" --help >/dev/null 2>&1; then
        print_success "Server binary is functional"
        return 0
    else
        print_error "Server binary test failed"
        return 1
    fi
}

# Get platform info
get_platform_info() {
    PLATFORM=$(uname -s)
    ARCH=$(uname -m)
    export PLATFORM ARCH
}

# Check for Metal support on macOS
check_metal_support() {
    if [[ "$PLATFORM" != "Darwin" ]]; then
        print_error "Metal support is only available on macOS"
        return 1
    fi
    
    # Check if we can build with Metal support
    print_info "Checking Metal support availability..."
    
    # Check for Xcode Command Line Tools
    if ! xcode-select -p &>/dev/null; then
        print_error "Xcode Command Line Tools not installed"
        print_info "Install with: xcode-select --install"
        return 1
    fi
    
    # Check for Metal framework (should be available on all modern Macs)
    if ! xcrun --show-sdk-path &>/dev/null; then
        print_error "Cannot locate macOS SDK"
        return 1
    fi
    
    print_info "Metal support is available"
    return 0
}

# Clone repository with timeout
clone_repository() {
    local repo_url="$1"
    local target_dir="$2"
    local version="$3"
    
    if ! timeout "$DEFAULT_GIT_TIMEOUT" git clone --depth 1 --branch "$version" "$repo_url" "$target_dir"; then
        print_error "Failed to clone repository"
        return 1
    fi
    return 0
}