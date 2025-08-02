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

# Default values
MODEL_NAME="${1:-}"
CONFIG_DIR="${MISTRAL_DIR}/config/models"
MISTRAL_CONFIG="${MISTRAL_DIR}/config/mistral/config.toml"

# Function to show usage
usage() {
    cat << EOF
Mistral Model Configuration Tool

Configure a model for use with Mistral.rs.

Usage: $0 [model_name]

Arguments:
    model_name    Name of the model to configure (optional)
                 If not provided, interactive mode will be used

Examples:
    $0                    # Interactive configuration
    $0 mistral-7b        # Configure specific model
    $0 list              # List available configurations

This tool will:
1. Help you select a model configuration
2. Set it as the default model in config.toml
3. Verify the model is downloaded
4. Optionally download the model if missing

EOF
}

# Function to list available configurations
list_configurations() {
    print_header "Available Model Configurations"
    echo ""
    
    local configs=()
    while IFS= read -r -d '' config; do
        local basename=$(basename "$config" .toml)
        if [[ "$basename" != "model-template" && "$basename" != "lora-adapter-template" ]]; then
            configs+=("$basename")
        fi
    done < <(find "$CONFIG_DIR" -name "*.toml" -print0 2>/dev/null | sort -z)
    
    if [ ${#configs[@]} -eq 0 ]; then
        print_error "No model configurations found"
        return 1
    fi
    
    for i in "${!configs[@]}"; do
        local config="${configs[$i]}"
        local config_file="${CONFIG_DIR}/${config}.toml"
        
        # Extract model info from config
        local model_id=$(grep -E '^\s*id\s*=' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "unknown")
        local size=$(grep -E '^\s*size\s*=' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "unknown")
        local context=$(grep -E '^\s*context_length\s*=' "$config_file" 2>/dev/null | awk '{print $NF}' || echo "unknown")
        
        printf "%2d. %-20s (ID: %-20s Size: %-6s Context: %s)\n" $((i+1)) "$config" "$model_id" "$size" "$context"
    done
    
    echo ""
    return 0
}

# Function to select configuration interactively
select_configuration() {
    local configs=()
    while IFS= read -r -d '' config; do
        local basename=$(basename "$config" .toml)
        if [[ "$basename" != "model-template" && "$basename" != "lora-adapter-template" ]]; then
            configs+=("$basename")
        fi
    done < <(find "$CONFIG_DIR" -name "*.toml" -print0 2>/dev/null | sort -z)
    
    if [ ${#configs[@]} -eq 0 ]; then
        print_error "No model configurations found"
        return 1
    fi
    
    list_configurations
    
    read -p "Select a configuration (1-${#configs[@]}): " selection
    
    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#configs[@]} ]; then
        print_error "Invalid selection"
        return 1
    fi
    
    echo "${configs[$((selection-1))]}"
}

# Function to update mistral config
update_mistral_config() {
    local model_config="$1"
    
    # Read model ID from config
    local model_id=$(grep -E '^\s*id\s*=' "$model_config" 2>/dev/null | cut -d'"' -f2)
    local model_path=$(grep -E '^\s*path\s*=' "$model_config" 2>/dev/null | cut -d'"' -f2)
    
    if [ -z "$model_id" ] || [ -z "$model_path" ]; then
        print_error "Invalid model configuration file"
        return 1
    fi
    
    print_info "Updating Mistral configuration..."
    
    # Create backup
    cp "$MISTRAL_CONFIG" "${MISTRAL_CONFIG}.bak"
    
    # Update the default model in config.toml
    # This is a simplified approach - in production you'd use a proper TOML parser
    if grep -q '^\s*default_model\s*=' "$MISTRAL_CONFIG"; then
        # Update existing
        sed -i.tmp "s/^\\s*default_model\\s*=.*/default_model = \"$model_id\"/" "$MISTRAL_CONFIG"
    else
        # Add new entry under [model] section
        awk -v model="default_model = \"$model_id\"" '
            /^\[model\]/ { print; print model; next }
            { print }
        ' "$MISTRAL_CONFIG" > "${MISTRAL_CONFIG}.new"
        mv "${MISTRAL_CONFIG}.new" "$MISTRAL_CONFIG"
    fi
    
    # Update model path
    if grep -q '^\s*model_path\s*=' "$MISTRAL_CONFIG"; then
        sed -i.tmp "s|^\\s*model_path\\s*=.*|model_path = \"$model_path\"|" "$MISTRAL_CONFIG"
    fi
    
    # Clean up temp files
    rm -f "${MISTRAL_CONFIG}.tmp"
    
    print_success "Configuration updated"
    echo ""
    echo "Default model set to: $model_id"
    echo "Model path: $model_path"
}

# Function to check if model exists
check_model_exists() {
    local model_path="$1"
    local full_path="${ROOT_DIR}/data/mistral-models/${model_path}"
    
    if [ -f "$full_path" ]; then
        print_success "Model file exists: $full_path"
        return 0
    else
        print_warning "Model file not found: $full_path"
        return 1
    fi
}

# Function to configure model
configure_model() {
    local model_name="$1"
    
    # Find configuration file
    local config_file=""
    if [ -n "$model_name" ]; then
        config_file="${CONFIG_DIR}/${model_name}.toml"
        if [ ! -f "$config_file" ]; then
            print_error "Configuration not found: $model_name"
            echo ""
            list_configurations
            return 1
        fi
    else
        # Interactive selection
        model_name=$(select_configuration)
        if [ -z "$model_name" ]; then
            return 1
        fi
        config_file="${CONFIG_DIR}/${model_name}.toml"
    fi
    
    print_header "Configuring Model: $model_name"
    echo ""
    
    # Display configuration details
    local model_id=$(grep -E '^\s*id\s*=' "$config_file" 2>/dev/null | cut -d'"' -f2)
    local model_path=$(grep -E '^\s*path\s*=' "$config_file" 2>/dev/null | cut -d'"' -f2)
    local size=$(grep -E '^\s*size\s*=' "$config_file" 2>/dev/null | cut -d'"' -f2)
    local quant=$(grep -E '^\s*quantization\s*=' "$config_file" 2>/dev/null | cut -d'"' -f2)
    
    echo "Model ID: $model_id"
    echo "Model Size: $size"
    echo "Quantization: $quant"
    echo "Model Path: $model_path"
    echo ""
    
    # Update mistral config
    update_mistral_config "$config_file"
    
    # Check if model exists
    if ! check_model_exists "$model_path"; then
        echo ""
        read -p "Would you like to download this model? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Downloading model..."
            "${SCRIPT_DIR}/pull-model.sh" "$model_id" "$quant"
        else
            print_info "Model not downloaded. You can download it later with:"
            echo "  ${SCRIPT_DIR}/pull-model.sh $model_id $quant"
        fi
    fi
    
    echo ""
    print_success "Model configuration complete!"
    echo ""
    echo "To use this model, restart the Mistral service:"
    echo "  cd $MISTRAL_DIR && docker-compose restart"
}

# Main script logic
case "${1:-}" in
    help|--help|-h)
        usage
        exit 0
        ;;
    list)
        list_configurations
        ;;
    "")
        # Interactive mode
        configure_model ""
        ;;
    *)
        # Configure specific model
        configure_model "$1"
        ;;
esac