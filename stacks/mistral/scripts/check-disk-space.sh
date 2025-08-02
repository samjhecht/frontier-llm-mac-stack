#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MISTRAL_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$(dirname "$MISTRAL_DIR")")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

# Load environment variables
if [ -f "${MISTRAL_DIR}/.env" ]; then
    source "${MISTRAL_DIR}/.env"
elif [ -f "${ROOT_DIR}/.env" ]; then
    source "${ROOT_DIR}/.env"
fi

# Default values
MISTRAL_MODELS_PATH="${MISTRAL_MODELS_PATH:-${ROOT_DIR}/data/mistral-models}"
MIN_FREE_SPACE_GB="${MIN_FREE_SPACE_GB:-10}"

# Function to show usage
usage() {
    cat << EOF
Mistral Disk Space Check Tool

Check disk space usage and availability for model storage.

Usage: $0 [min_free_gb]

Arguments:
    min_free_gb    Minimum free space required in GB (default: 10)

Examples:
    $0              # Check with default 10GB minimum
    $0 50           # Check for at least 50GB free space

EOF
}

# Function to format bytes
format_bytes() {
    local bytes="$1"
    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec-i --suffix=B "$bytes" 2>/dev/null || echo "${bytes}B"
    else
        # Manual conversion
        local gb=$((bytes / 1024 / 1024 / 1024))
        local mb=$(((bytes / 1024 / 1024) % 1024))
        if [ $gb -gt 0 ]; then
            echo "${gb}.${mb:0:1}GiB"
        else
            echo "${mb}MiB"
        fi
    fi
}

# Function to get disk usage
get_disk_usage() {
    local path="$1"
    
    # Create directory if it doesn't exist (for df to work)
    mkdir -p "$path"
    
    # Get disk usage information
    if command -v df >/dev/null 2>&1; then
        # Parse df output
        local df_output=$(df -k "$path" 2>/dev/null | tail -1)
        if [ -n "$df_output" ]; then
            local total_kb=$(echo "$df_output" | awk '{print $2}')
            local used_kb=$(echo "$df_output" | awk '{print $3}')
            local available_kb=$(echo "$df_output" | awk '{print $4}')
            local percent=$(echo "$df_output" | awk '{print $5}' | tr -d '%')
            local mount=$(echo "$df_output" | awk '{print $NF}')
            
            # Convert to bytes
            local total=$((total_kb * 1024))
            local used=$((used_kb * 1024))
            local available=$((available_kb * 1024))
            
            echo "$total|$used|$available|$percent|$mount"
        fi
    fi
}

# Function to analyze model sizes
analyze_models() {
    local path="$1"
    local model_count=0
    local total_size=0
    local largest_size=0
    local largest_name=""
    
    if [ -d "$path" ]; then
        while IFS= read -r -d '' file; do
            local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
            total_size=$((total_size + size))
            ((model_count++))
            
            if [ $size -gt $largest_size ]; then
                largest_size=$size
                largest_name=$(basename "$file")
            fi
        done < <(find "$path" -type f \( -name "*.gguf" -o -name "*.safetensors" -o -name "*.bin" -o -name "*.pth" \) -print0 2>/dev/null)
    fi
    
    echo "$model_count|$total_size|$largest_size|$largest_name"
}

# Function to estimate model requirements
estimate_requirements() {
    local available="$1"
    
    print_header "Estimated Model Capacity"
    echo ""
    
    # Common model sizes (approximate)
    declare -A MODEL_SIZES=(
        ["7B-Q4"]=$((4 * 1024 * 1024 * 1024))      # 4GB
        ["7B-Q8"]=$((8 * 1024 * 1024 * 1024))      # 8GB
        ["13B-Q4"]=$((8 * 1024 * 1024 * 1024))     # 8GB
        ["13B-Q8"]=$((16 * 1024 * 1024 * 1024))    # 16GB
        ["70B-Q4"]=$((40 * 1024 * 1024 * 1024))    # 40GB
        ["Mixtral-Q4"]=$((26 * 1024 * 1024 * 1024)) # 26GB
    )
    
    echo "Based on available space, you can store approximately:"
    for model in "7B-Q4" "7B-Q8" "13B-Q4" "13B-Q8" "70B-Q4" "Mixtral-Q4"; do
        local size=${MODEL_SIZES[$model]}
        local count=$((available / size))
        if [ $count -gt 0 ]; then
            printf "  - %-12s models: %d\n" "$model" "$count"
        fi
    done
}

# Main disk space check
check_disk_space() {
    local min_free_gb="${1:-$MIN_FREE_SPACE_GB}"
    local min_free_bytes=$((min_free_gb * 1024 * 1024 * 1024))
    
    print_header "Disk Space Analysis"
    echo ""
    
    # Get disk usage
    local disk_info=$(get_disk_usage "$MISTRAL_MODELS_PATH")
    if [ -z "$disk_info" ]; then
        print_error "Unable to get disk information"
        return 1
    fi
    
    IFS='|' read -r total used available percent mount <<< "$disk_info"
    
    # Get model statistics
    local model_info=$(analyze_models "$MISTRAL_MODELS_PATH")
    IFS='|' read -r model_count model_total largest_size largest_name <<< "$model_info"
    
    # Display disk information
    print_info "Models Directory: $MISTRAL_MODELS_PATH"
    print_info "Mount Point: $mount"
    echo ""
    
    echo "Disk Usage:"
    printf "  %-20s %s\n" "Total capacity:" "$(format_bytes $total)"
    printf "  %-20s %s (%s%%)\n" "Used space:" "$(format_bytes $used)" "$percent"
    printf "  %-20s %s\n" "Available space:" "$(format_bytes $available)"
    echo ""
    
    echo "Model Storage:"
    printf "  %-20s %d\n" "Number of models:" "$model_count"
    printf "  %-20s %s\n" "Total model size:" "$(format_bytes $model_total)"
    if [ -n "$largest_name" ] && [ $largest_size -gt 0 ]; then
        printf "  %-20s %s (%s)\n" "Largest model:" "$largest_name" "$(format_bytes $largest_size)"
    fi
    
    # Calculate model percentage of used space
    if [ $used -gt 0 ] && [ $model_total -gt 0 ]; then
        local model_percent=$((model_total * 100 / used))
        printf "  %-20s %d%% of used space\n" "Models usage:" "$model_percent"
    fi
    
    echo ""
    
    # Check available space
    if [ $available -lt $min_free_bytes ]; then
        print_warning "Low disk space warning!"
        print_error "Available space ($(format_bytes $available)) is below minimum requirement ($(format_bytes $min_free_bytes))"
        echo ""
        echo "Recommendations:"
        echo "  1. Delete unused models with: $SCRIPT_DIR/delete-model.sh"
        echo "  2. Move models to a different disk"
        echo "  3. Increase disk capacity"
    else
        print_success "Sufficient disk space available"
    fi
    
    echo ""
    estimate_requirements "$available"
}

# Main script logic
case "${1:-}" in
    help|--help|-h)
        usage
        exit 0
        ;;
    "")
        check_disk_space "$MIN_FREE_SPACE_GB"
        ;;
    *)
        if [[ "$1" =~ ^[0-9]+$ ]]; then
            check_disk_space "$1"
        else
            print_error "Invalid argument: $1"
            usage
            exit 1
        fi
        ;;
esac