#!/bin/bash
# Configuration Validation Script for Frontier LLM Stack
# Validates environment configuration, dependencies, and prerequisites

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source common functions
source "$SCRIPT_DIR/common-functions.sh"

# Configuration
REQUIRED_COMMANDS=("docker" "docker-compose" "git" "curl")
REQUIRED_DOCKER_VERSION="20.10.0"
REQUIRED_COMPOSE_VERSION="2.0.0"
MIN_MEMORY_GB=16
MIN_DISK_GB=50

# Track validation results
VALIDATION_ERRORS=0
VALIDATION_WARNINGS=0

# Function to compare versions
version_ge() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$2" ]
}

# Validate Docker installation
validate_docker() {
    print_header "Validating Docker"
    
    if ! command_exists docker; then
        print_error "Docker is not installed"
        ((VALIDATION_ERRORS++))
        return 1
    fi
    
    # Check Docker version
    local docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if version_ge "$docker_version" "$REQUIRED_DOCKER_VERSION"; then
        print_success "Docker version $docker_version meets requirements (>= $REQUIRED_DOCKER_VERSION)"
    else
        print_warning "Docker version $docker_version is older than recommended $REQUIRED_DOCKER_VERSION"
        ((VALIDATION_WARNINGS++))
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon is not running"
        ((VALIDATION_ERRORS++))
        return 1
    fi
    
    print_success "Docker daemon is running"
    
    # Check Docker resources
    local docker_mem_gb=$(docker info 2>/dev/null | grep "Total Memory" | grep -oE '[0-9]+' | head -1)
    if [ -n "$docker_mem_gb" ]; then
        if [ "$docker_mem_gb" -lt "$MIN_MEMORY_GB" ]; then
            print_warning "Docker memory ${docker_mem_gb}GB is less than recommended ${MIN_MEMORY_GB}GB"
            ((VALIDATION_WARNINGS++))
        else
            print_success "Docker memory allocation: ${docker_mem_gb}GB"
        fi
    fi
    
    return 0
}

# Validate Docker Compose
validate_docker_compose() {
    print_header "Validating Docker Compose"
    
    if ! command_exists docker-compose; then
        print_error "Docker Compose is not installed"
        ((VALIDATION_ERRORS++))
        return 1
    fi
    
    # Check version
    local compose_version=$(docker-compose version --short 2>/dev/null || docker-compose --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if version_ge "$compose_version" "$REQUIRED_COMPOSE_VERSION"; then
        print_success "Docker Compose version $compose_version meets requirements (>= $REQUIRED_COMPOSE_VERSION)"
    else
        print_warning "Docker Compose version $compose_version is older than recommended $REQUIRED_COMPOSE_VERSION"
        ((VALIDATION_WARNINGS++))
    fi
    
    return 0
}

# Validate system resources
validate_system_resources() {
    print_header "Validating System Resources"
    
    # Check memory
    local sys_mem_gb=$(get_system_memory_gb)
    if [ "$sys_mem_gb" -lt "$MIN_MEMORY_GB" ]; then
        print_error "System memory ${sys_mem_gb}GB is less than minimum ${MIN_MEMORY_GB}GB"
        ((VALIDATION_ERRORS++))
    else
        print_success "System memory: ${sys_mem_gb}GB"
    fi
    
    # Check disk space
    if ! check_disk_space "$PROJECT_ROOT" "$MIN_DISK_GB"; then
        print_error "Insufficient disk space (minimum ${MIN_DISK_GB}GB required)"
        ((VALIDATION_ERRORS++))
    else
        local available_gb=$(df -BG "$PROJECT_ROOT" | awk 'NR==2 {print $4}' | sed 's/G//')
        print_success "Available disk space: ${available_gb}GB"
    fi
    
    # Check CPU
    local cpu_count=$(get_cpu_count)
    if [ "$cpu_count" -lt 4 ]; then
        print_warning "CPU cores: $cpu_count (4+ recommended for good performance)"
        ((VALIDATION_WARNINGS++))
    else
        print_success "CPU cores: $cpu_count"
    fi
    
    # Detect GPU
    local gpu_type=$(detect_gpu)
    if [ "$gpu_type" != "none" ]; then
        print_success "GPU detected: $gpu_type"
    else
        print_warning "No GPU detected - inference will be CPU-only (slower)"
        ((VALIDATION_WARNINGS++))
    fi
}

# Validate required commands
validate_commands() {
    print_header "Validating Required Commands"
    
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        if command_exists "$cmd"; then
            print_success "$cmd is installed"
        else
            print_error "$cmd is not installed"
            ((VALIDATION_ERRORS++))
        fi
    done
}

# Validate environment variables
validate_environment() {
    print_header "Validating Environment Configuration"
    
    # Load .env file if it exists
    if [ -f "$PROJECT_ROOT/.env" ]; then
        load_env "$PROJECT_ROOT/.env"
        print_success "Loaded .env file"
    else
        print_warning "No .env file found - using defaults"
        ((VALIDATION_WARNINGS++))
    fi
    
    # Check current stack selection
    if [ -f "$PROJECT_ROOT/.current_stack" ]; then
        local current_stack=$(cat "$PROJECT_ROOT/.current_stack")
        print_success "Current stack: $current_stack"
    else
        print_warning "No stack selected - run ./stack-select.sh to select a stack"
        ((VALIDATION_WARNINGS++))
    fi
}

# Validate network configuration
validate_network() {
    print_header "Validating Network Configuration"
    
    # Check if required ports are available
    local ports=(
        "8080:Mistral API"
        "11434:Ollama/Proxy API"
        "9090:Prometheus"
        "3000:Grafana"
        "9100:Node Exporter"
    )
    
    for port_spec in "${ports[@]}"; do
        local port=$(echo "$port_spec" | cut -d: -f1)
        local service=$(echo "$port_spec" | cut -d: -f2)
        
        if check_port_available "$port"; then
            print_success "Port $port ($service) is available"
        else
            print_warning "Port $port ($service) is already in use"
            ((VALIDATION_WARNINGS++))
        fi
    done
    
    # Check Docker networks
    if docker network inspect frontier-llm-network >/dev/null 2>&1; then
        print_success "Docker network 'frontier-llm-network' exists"
    else
        print_info "Docker network 'frontier-llm-network' will be created on first run"
    fi
}

# Validate directory structure
validate_directories() {
    print_header "Validating Directory Structure"
    
    local required_dirs=(
        "stacks/common"
        "stacks/mistral"
        "stacks/ollama"
        "data"
        "scripts"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ -d "$PROJECT_ROOT/$dir" ]; then
            print_success "Directory exists: $dir"
        else
            print_error "Missing directory: $dir"
            ((VALIDATION_ERRORS++))
        fi
    done
}

# Main validation function
main() {
    print_header "Frontier LLM Stack Configuration Validator"
    echo "Project Root: $PROJECT_ROOT"
    echo ""
    
    # Run all validations
    validate_commands
    validate_docker
    validate_docker_compose
    validate_system_resources
    validate_environment
    validate_directories
    validate_network
    
    # Summary
    echo ""
    print_header "Validation Summary"
    
    if [ $VALIDATION_ERRORS -eq 0 ]; then
        if [ $VALIDATION_WARNINGS -eq 0 ]; then
            print_success "All checks passed! Your system is ready."
        else
            print_success "Configuration is valid with $VALIDATION_WARNINGS warning(s)"
            print_info "Review warnings above for optimal performance"
        fi
        exit 0
    else
        print_error "Validation failed with $VALIDATION_ERRORS error(s) and $VALIDATION_WARNINGS warning(s)"
        print_info "Please fix the errors above before proceeding"
        exit 1
    fi
}

# Run main function
main "$@"