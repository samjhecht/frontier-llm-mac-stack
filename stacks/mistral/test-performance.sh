#!/bin/bash
# Test script to validate Mistral performance optimizations

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "ℹ $1"; }

# Check if .env exists
check_env_file() {
    print_info "Checking environment configuration..."
    
    if [ ! -f "$SCRIPT_DIR/.env" ]; then
        print_warning ".env file not found. Creating from .env.example..."
        cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
        print_info "Please review and adjust settings in $SCRIPT_DIR/.env"
    else
        print_success "Environment file found"
    fi
    
    # Check for Metal settings
    if grep -q "MISTRAL_DEVICE=metal" "$SCRIPT_DIR/.env"; then
        print_success "Metal acceleration configured"
    else
        print_warning "Metal acceleration not enabled in .env"
    fi
}

# Validate Metal configuration
validate_metal_config() {
    print_info "Validating Metal configuration..."
    
    # Check if running on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        print_warning "Not running on macOS, Metal acceleration unavailable"
        return 1
    fi
    
    # Check for Metal support
    if system_profiler SPDisplaysDataType 2>/dev/null | grep -q "Metal"; then
        print_success "Metal-capable GPU detected"
        system_profiler SPDisplaysDataType 2>/dev/null | grep -E "Chipset Model:|VRAM" | head -2
    else
        print_error "No Metal-capable GPU found"
        return 1
    fi
    
    # Check Docker Desktop resources
    if command -v docker &> /dev/null; then
        local docker_memory=$(docker system info 2>/dev/null | grep "Total Memory" | awk '{print $3}')
        if [ -n "$docker_memory" ]; then
            print_info "Docker Desktop memory allocation: ${docker_memory}"
            
            # Extract numeric value and check if sufficient
            local mem_value=$(echo "$docker_memory" | grep -o '[0-9.]*')
            if (( $(echo "$mem_value < 32" | bc -l) )); then
                print_warning "Docker Desktop memory allocation might be insufficient for optimal performance"
                print_info "Recommended: Allocate at least 32GB in Docker Desktop preferences"
            fi
        fi
    fi
}

# Test configuration loading
test_config_loading() {
    print_info "Testing configuration files..."
    
    # Check TOML syntax
    if command -v python3 &> /dev/null; then
        python3 -c "import tomli; tomli.load(open('$SCRIPT_DIR/config/mistral/config.toml', 'rb'))" 2>/dev/null && \
            print_success "config.toml syntax valid" || \
            print_error "config.toml has syntax errors"
    else
        print_warning "Python not available, skipping TOML validation"
    fi
    
    # Check model configs
    for config in "$SCRIPT_DIR/config/models"/*.toml; do
        if [ -f "$config" ]; then
            basename "$config" | xargs -I {} echo "  Found model config: {}"
        fi
    done
}

# Verify performance settings
verify_performance_settings() {
    print_info "Verifying performance settings..."
    
    # Load .env file
    if [ -f "$SCRIPT_DIR/.env" ]; then
        source "$SCRIPT_DIR/.env"
        
        # Check critical performance settings
        local settings_ok=true
        
        # Metal settings
        if [[ "${MISTRAL_DEVICE:-}" == "metal" ]]; then
            print_success "Metal device enabled"
        else
            print_warning "MISTRAL_DEVICE not set to 'metal'"
            settings_ok=false
        fi
        
        # Flash attention
        if [[ "${MISTRAL_USE_FLASH_ATTENTION:-}" == "true" ]]; then
            print_success "Flash attention enabled"
        else
            print_warning "Flash attention disabled (impacts performance)"
        fi
        
        # Memory pooling
        if [[ "${MISTRAL_ENABLE_MEMORY_POOLING:-}" == "true" ]]; then
            print_success "Memory pooling enabled"
        else
            print_warning "Memory pooling disabled"
        fi
        
        # Continuous batching
        if [[ "${MISTRAL_ENABLE_CONTINUOUS_BATCHING:-}" == "true" ]]; then
            print_success "Continuous batching enabled"
        else
            print_warning "Continuous batching disabled"
        fi
        
        # Quantization
        if [[ -n "${MISTRAL_DEFAULT_QUANTIZATION:-}" ]]; then
            print_info "Default quantization: ${MISTRAL_DEFAULT_QUANTIZATION}"
        fi
        
        if [ "$settings_ok" = true ]; then
            print_success "All critical performance settings configured"
        else
            print_warning "Some performance settings need attention"
        fi
    fi
}

# Test service startup
test_service_startup() {
    print_info "Testing service startup with performance settings..."
    
    # Check if service is already running
    if docker ps | grep -q "frontier-mistral"; then
        print_warning "Mistral service already running. Checking configuration..."
        
        # Check environment variables in running container
        docker exec frontier-mistral env | grep -E "MISTRAL_DEVICE|METAL" | head -5
    else
        print_info "Service not running. Start with: $PROJECT_ROOT/scripts/mistral-start.sh"
    fi
}

# Generate performance test summary
generate_summary() {
    print_info "\nPerformance Configuration Summary:"
    echo "=================================="
    
    # Hardware info
    echo "Hardware:"
    echo "  CPU: $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")"
    echo "  Memory: $(sysctl -n hw.memsize 2>/dev/null | awk '{print int($1/1024/1024/1024) " GB"}' || echo "Unknown")"
    
    if system_profiler SPDisplaysDataType 2>/dev/null | grep -q "Ultra"; then
        echo "  GPU: Mac Studio Ultra detected - optimal for large models"
    fi
    
    echo ""
    echo "Next Steps:"
    echo "1. Review and adjust settings in $SCRIPT_DIR/.env"
    echo "2. Start the service: $PROJECT_ROOT/scripts/mistral-start.sh"
    echo "3. Run benchmarks: $PROJECT_ROOT/scripts/testing/benchmark-mistral.sh"
    echo "4. Monitor performance: http://localhost:3000 (Grafana)"
    echo ""
    echo "Documentation: $PROJECT_ROOT/docs/performance-tuning.md"
}

# Main execution
main() {
    echo "Mistral Performance Configuration Test"
    echo "====================================="
    echo ""
    
    check_env_file
    echo ""
    
    validate_metal_config
    echo ""
    
    test_config_loading
    echo ""
    
    verify_performance_settings
    echo ""
    
    test_service_startup
    echo ""
    
    generate_summary
}

main "$@"