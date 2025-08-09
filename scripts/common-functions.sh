#!/bin/bash
# Common Functions Library for Frontier LLM Stack
# Source this file in other scripts: source "$(dirname "${BASH_SOURCE[0]}")/common-functions.sh"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print functions
print_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

print_info() {
    echo -e "${YELLOW}INFO: $1${NC}"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

print_debug() {
    if [ "${DEBUG:-0}" = "1" ]; then
        echo -e "${CYAN}DEBUG: $1${NC}" >&2
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check Docker daemon
check_docker() {
    if ! command_exists docker; then
        print_error "Docker is not installed"
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon is not running"
        return 1
    fi
    
    return 0
}

# Create Docker network if it doesn't exist
ensure_docker_network() {
    local network_name="${1:-frontier-llm-network}"
    
    if ! docker network inspect "$network_name" >/dev/null 2>&1; then
        print_info "Creating Docker network: $network_name"
        if ! docker network create "$network_name" 2>/dev/null; then
            # Check if the network now exists (created by another process)
            if docker network inspect "$network_name" >/dev/null 2>&1; then
                print_info "Network $network_name already exists (created by another process)"
            else
                print_error "Failed to create network: $network_name"
                return 1
            fi
        fi
    else
        print_debug "Network $network_name already exists"
    fi
    
    return 0
}

# Load environment variables from .env file
load_env() {
    local env_file="${1:-.env}"
    
    if [ -f "$env_file" ]; then
        print_debug "Loading environment from $env_file"
        # Export variables while avoiding command injection
        set -a
        source "$env_file"
        set +a
    else
        print_debug "No .env file found at $env_file"
    fi
}

# Validate required environment variables
validate_env_vars() {
    local required_vars=("$@")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        print_error "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi
    
    return 0
}

# Check if port is available
check_port_available() {
    local port=$1
    local host="${2:-localhost}"
    
    if command_exists nc; then
        if nc -z "$host" "$port" 2>/dev/null; then
            return 1  # Port is in use
        fi
    elif command_exists lsof; then
        if lsof -i ":$port" >/dev/null 2>&1; then
            return 1  # Port is in use
        fi
    else
        print_warning "Cannot check port availability (nc or lsof not found)"
    fi
    
    return 0  # Port is available
}

# Wait for service to be ready
wait_for_service() {
    local url=$1
    local max_attempts="${2:-30}"
    local delay="${3:-2}"
    local attempt=0
    
    print_info "Waiting for service at $url..."
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -sf "$url" >/dev/null 2>&1; then
            print_success "Service is ready at $url"
            return 0
        fi
        
        attempt=$((attempt + 1))
        print_debug "Attempt $attempt/$max_attempts failed, waiting ${delay}s..."
        sleep "$delay"
    done
    
    print_error "Service at $url did not become ready after $max_attempts attempts"
    return 1
}

# Get container status
get_container_status() {
    local container_name=$1
    
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "^${container_name}"; then
        docker ps --format "table {{.Names}}\t{{.Status}}" | grep "^${container_name}" | awk '{$1=""; print $0}' | sed 's/^ //'
    else
        echo "Not running"
    fi
}

# Check disk space
check_disk_space() {
    local path="${1:-.}"
    local min_gb="${2:-10}"
    
    local available_kb
    if [[ "$OSTYPE" == "darwin"* ]]; then
        available_kb=$(df -k "$path" | awk 'NR==2 {print $4}')
    else
        available_kb=$(df -k "$path" | awk 'NR==2 {print $4}')
    fi
    
    local available_gb=$((available_kb / 1024 / 1024))
    
    if [ "$available_gb" -lt "$min_gb" ]; then
        print_warning "Low disk space: ${available_gb}GB available (minimum recommended: ${min_gb}GB)"
        return 1
    else
        print_debug "Disk space OK: ${available_gb}GB available"
        return 0
    fi
}

# Get system memory in GB
get_system_memory_gb() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        local mem_bytes=$(sysctl -n hw.memsize)
        echo $((mem_bytes / 1024 / 1024 / 1024))
    else
        # Linux
        local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        echo $((mem_kb / 1024 / 1024))
    fi
}

# Get CPU count
get_cpu_count() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sysctl -n hw.ncpu
    else
        nproc
    fi
}

# Detect GPU availability
detect_gpu() {
    local gpu_type="none"
    
    # Check for NVIDIA GPU
    if command_exists nvidia-smi && nvidia-smi >/dev/null 2>&1; then
        gpu_type="nvidia"
        print_info "NVIDIA GPU detected"
    # Check for AMD GPU (Linux)
    elif [ -f /sys/class/drm/card0/device/vendor ] && grep -q "0x1002" /sys/class/drm/card0/device/vendor; then
        gpu_type="amd"
        print_info "AMD GPU detected"
    # Check for Apple Silicon (macOS)
    elif [[ "$OSTYPE" == "darwin"* ]] && sysctl -n machdep.cpu.brand_string | grep -q "Apple"; then
        gpu_type="apple"
        print_info "Apple Silicon detected"
    else
        print_info "No GPU detected, will use CPU"
    fi
    
    echo "$gpu_type"
}

# Create a progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=50
    
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    
    printf "\r["
    printf "%${filled}s" | tr ' ' '='
    printf "%$((width - filled))s" | tr ' ' ' '
    printf "] %3d%%" "$percent"
    
    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

# Confirm action with user
confirm_action() {
    local prompt="${1:-Continue?}"
    local default="${2:-n}"
    
    local response
    if [ "$default" = "y" ]; then
        read -p "$prompt [Y/n]: " response
        response=${response:-y}
    else
        read -p "$prompt [y/N]: " response
        response=${response:-n}
    fi
    
    [[ "$response" =~ ^[Yy]$ ]]
}

# Export functions for use in subshells
export -f print_error
export -f print_success
export -f print_info
export -f print_header
export -f print_warning
export -f print_debug
export -f command_exists