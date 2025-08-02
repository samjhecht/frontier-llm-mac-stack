#!/bin/bash
# Validate Mistral configuration for Docker and Metal settings

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "ℹ $1"; }

# Check Docker Desktop memory allocation
check_docker_memory() {
    print_info "Checking Docker Desktop memory allocation..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker not found"
        return 1
    fi
    
    # Get Docker info
    if docker info &> /dev/null; then
        # Try to get memory from Docker Desktop settings
        local docker_memory=""
        
        # macOS Docker Desktop stores settings in different locations
        local settings_files=(
            "$HOME/Library/Group Containers/group.com.docker/settings.json"
            "$HOME/.docker/daemon.json"
        )
        
        for settings_file in "${settings_files[@]}"; do
            if [ -f "$settings_file" ]; then
                # Try to extract memory setting
                if command -v jq &> /dev/null; then
                    docker_memory=$(jq -r '.memoryMiB // empty' "$settings_file" 2>/dev/null || true)
                    if [ -n "$docker_memory" ]; then
                        local memory_gb=$((docker_memory / 1024))
                        print_info "Docker Desktop allocated memory: ${memory_gb}GB"
                        
                        # Check against .env settings
                        if [ -f "$SCRIPT_DIR/.env" ]; then
                            local mistral_memory=$(grep "MISTRAL_MEMORY_LIMIT=" "$SCRIPT_DIR/.env" | cut -d'=' -f2 | grep -o '[0-9]*' || echo "0")
                            if [ "$mistral_memory" -gt 0 ] && [ "$memory_gb" -lt "$mistral_memory" ]; then
                                print_warning "Docker Desktop memory (${memory_gb}GB) is less than MISTRAL_MEMORY_LIMIT (${mistral_memory}GB)"
                                print_info "Increase Docker Desktop memory in Preferences > Resources"
                            else
                                print_success "Docker memory allocation is sufficient"
                            fi
                        fi
                        break
                    fi
                fi
            fi
        done
        
        if [ -z "$docker_memory" ]; then
            print_warning "Could not determine Docker Desktop memory allocation"
            print_info "Ensure Docker Desktop has at least 32GB allocated in Preferences > Resources"
        fi
    else
        print_error "Docker daemon is not running"
        return 1
    fi
}

# Validate Metal device ID
validate_metal_device() {
    print_info "Validating Metal device configuration..."
    
    if [[ "$(uname)" != "Darwin" ]]; then
        print_warning "Not running on macOS, Metal validation skipped"
        return 0
    fi
    
    # Check system_profiler for Metal devices
    if command -v system_profiler &> /dev/null; then
        local gpu_count=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -c "Chipset Model:" || echo "0")
        
        if [ "$gpu_count" -gt 0 ]; then
            print_success "Found $gpu_count Metal-capable GPU(s)"
            
            # Check configured device ID
            if [ -f "$SCRIPT_DIR/.env" ]; then
                local device_id=$(grep "MISTRAL_METAL_DEVICE_ID=" "$SCRIPT_DIR/.env" | cut -d'=' -f2 || echo "0")
                if [ "$device_id" -ge "$gpu_count" ]; then
                    print_error "MISTRAL_METAL_DEVICE_ID=$device_id is invalid (only $gpu_count GPU(s) available)"
                    print_info "Set MISTRAL_METAL_DEVICE_ID to a value between 0 and $((gpu_count - 1))"
                    return 1
                else
                    print_success "Metal device ID $device_id is valid"
                fi
            fi
            
            # Show GPU details
            print_info "Available Metal devices:"
            system_profiler SPDisplaysDataType 2>/dev/null | grep -A1 "Chipset Model:" | grep -v "^--$" | sed 's/^/  /'
        else
            print_error "No Metal-capable GPUs found"
            return 1
        fi
    else
        print_warning "system_profiler not available, cannot validate Metal devices"
    fi
}

# Check if Metal Performance Shaders are available
check_metal_performance() {
    if [[ "$(uname)" != "Darwin" ]]; then
        return 0
    fi
    
    print_info "Checking Metal Performance Shaders support..."
    
    # Create a simple Swift program to check MPS availability
    local temp_swift=$(mktemp /tmp/check_mps.XXXXXX.swift)
    cat > "$temp_swift" << 'EOF'
import Metal
import MetalPerformanceShaders

let device = MTLCreateSystemDefaultDevice()
if let device = device {
    if MPSSupportsMTLDevice(device) {
        print("MPS supported")
        exit(0)
    } else {
        print("MPS not supported")
        exit(1)
    }
} else {
    print("No Metal device")
    exit(1)
}
EOF
    
    if command -v swift &> /dev/null; then
        if swift "$temp_swift" 2>/dev/null; then
            print_success "Metal Performance Shaders supported"
        else
            print_warning "Metal Performance Shaders not fully supported"
        fi
    else
        print_warning "Swift not available, cannot check MPS support"
    fi
    
    rm -f "$temp_swift"
}

# Main validation
main() {
    echo "Mistral Configuration Validator"
    echo "==============================="
    echo ""
    
    local validation_passed=true
    
    # Check Docker memory
    if ! check_docker_memory; then
        validation_passed=false
    fi
    echo ""
    
    # Validate Metal device
    if ! validate_metal_device; then
        validation_passed=false
    fi
    echo ""
    
    # Check Metal performance
    check_metal_performance
    echo ""
    
    # Summary
    if [ "$validation_passed" = true ]; then
        print_success "Configuration validation passed"
    else
        print_error "Configuration validation failed"
        echo ""
        echo "Please fix the issues above before running Mistral"
        exit 1
    fi
}

# Run validation
main "$@"