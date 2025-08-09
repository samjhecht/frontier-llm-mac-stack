#!/bin/bash

# Mistral Model Download Helper Script

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

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
if [ -f "${SCRIPT_DIR}/.env" ]; then
    source "${SCRIPT_DIR}/.env"
elif [ -f "${ROOT_DIR}/.env" ]; then
    source "${ROOT_DIR}/.env"
fi

# Set defaults
MISTRAL_MODELS_PATH=${MISTRAL_MODELS_PATH:-"${ROOT_DIR}/data/mistral-models"}

# Function to show usage
usage() {
    cat << EOF
Mistral Model Download Helper

This script helps you download and set up models for the Mistral stack.

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    list-available    List popular models available for download
    download <url>    Download a model from a direct URL
    info <model>      Show information about a specific model
    check            Check current models in the models directory
    help             Show this help message

Examples:
    $0 list-available
    $0 download https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.2-GGUF/resolve/main/mistral-7b-instruct-v0.2.Q4_K_M.gguf
    $0 check

Model Format Requirements:
    - GGUF format (recommended)
    - SafeTensors format
    - Quantized models: Q4_K_M, Q5_K_M, Q8_0, etc.

EOF
}

# Function to list available models
list_available() {
    print_header "Popular Mistral-Compatible Models"
    echo ""
    echo "1. Mistral 7B Instruct v0.2 (GGUF)"
    echo "   - Q4_K_M (4-bit, ~4GB): Best balance of size and quality"
    echo "   - Q5_K_M (5-bit, ~5GB): Higher quality, moderate size"
    echo "   - Q8_0 (8-bit, ~8GB): Near full quality"
    echo "   URL: https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.2-GGUF"
    echo ""
    echo "2. Mixtral 8x7B Instruct (GGUF)"
    echo "   - Q4_K_M (4-bit, ~26GB): Good for most uses"
    echo "   - Q5_K_M (5-bit, ~32GB): Better quality"
    echo "   URL: https://huggingface.co/TheBloke/Mixtral-8x7B-Instruct-v0.1-GGUF"
    echo ""
    echo "3. OpenHermes 2.5 Mistral 7B (GGUF)"
    echo "   - Q4_K_M (4-bit, ~4GB): Fine-tuned on high-quality data"
    echo "   - Q5_K_M (5-bit, ~5GB): Better response quality"
    echo "   URL: https://huggingface.co/TheBloke/OpenHermes-2.5-Mistral-7B-GGUF"
    echo ""
    echo "4. Codestral 22B (GGUF)"
    echo "   - Q4_K_M (4-bit, ~13GB): Specialized for code"
    echo "   - Q5_K_M (5-bit, ~16GB): Better code understanding"
    echo "   URL: https://huggingface.co/TheBloke/Codestral-22B-v0.1-GGUF"
    echo ""
    print_info "To download, copy the URL and use: $0 download <url>"
}

# Function to validate URL
validate_url() {
    local url="$1"
    # Basic URL validation
    if [[ ! "$url" =~ ^https?:// ]]; then
        print_error "Invalid URL: must start with http:// or https://"
        return 1
    fi
    # Check if URL is reachable
    if command -v curl >/dev/null 2>&1; then
        if ! curl -s -f -I "$url" >/dev/null 2>&1; then
            print_error "URL is not reachable or does not exist"
            return 1
        fi
    fi
    return 0
}

# Function to download a model
download_model() {
    local url="$1"
    local filename=$(basename "$url")
    
    # Validate URL
    if ! validate_url "$url"; then
        exit 1
    fi
    
    # Create models directory if it doesn't exist
    if [ ! -d "$MISTRAL_MODELS_PATH" ]; then
        print_info "Creating models directory: $MISTRAL_MODELS_PATH"
        mkdir -p "$MISTRAL_MODELS_PATH"
    fi
    
    local filepath="${MISTRAL_MODELS_PATH}/${filename}"
    
    # Check if file already exists
    if [ -f "$filepath" ]; then
        print_warning "Model file already exists: $filename"
        read -p "Do you want to overwrite it? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Download cancelled"
            return
        fi
    fi
    
    print_info "Downloading model: $filename"
    print_info "Destination: $filepath"
    
    # Warn about large file sizes
    print_warning "Model files can be very large (5-50GB+). Ensure you have sufficient disk space."
    print_info "The download will show progress. Press Ctrl+C to cancel if needed."
    echo ""
    
    # Download with progress bar
    if command -v wget >/dev/null 2>&1; then
        wget --show-progress -O "$filepath" "$url"
    elif command -v curl >/dev/null 2>&1; then
        curl -L --progress-bar -o "$filepath" "$url"
    else
        print_error "Neither wget nor curl is available. Please install one of them."
        exit 1
    fi
    
    if [ $? -eq 0 ]; then
        # Verify file is not empty
        if [ ! -s "$filepath" ]; then
            print_error "Downloaded file is empty"
            rm -f "$filepath"
            exit 1
        fi
        
        # Verify file is a valid model file (basic check)
        local file_type=$(file -b "$filepath" 2>/dev/null || echo "unknown")
        if [[ ! "$filename" =~ \.(gguf|safetensors|bin)$ ]]; then
            print_warning "File may not be a valid model format (expected .gguf, .safetensors, or .bin)"
        fi
        
        # Calculate and display SHA256 checksum for integrity verification
        if command -v sha256sum >/dev/null 2>&1; then
            local checksum=$(sha256sum "$filepath" | awk '{print $1}')
            print_info "SHA256: $checksum"
            # Save checksum to a file for future verification
            echo "$checksum  $filename" > "${filepath}.sha256"
        elif command -v shasum >/dev/null 2>&1; then
            local checksum=$(shasum -a 256 "$filepath" | awk '{print $1}')
            print_info "SHA256: $checksum"
            echo "$checksum  $filename" > "${filepath}.sha256"
        fi
        
        print_success "Model downloaded successfully!"
        print_info "File size: $(du -h "$filepath" | cut -f1)"
        echo ""
        print_info "To use this model, specify it in your API requests:"
        echo "  \"model\": \"$filename\""
    else
        print_error "Download failed"
        rm -f "$filepath"
        exit 1
    fi
}

# Function to show model info
show_model_info() {
    local model="$1"
    
    case "$model" in
        "mistral-7b"|"mistral")
            print_header "Mistral 7B Instruct v0.2"
            echo "A 7B parameter model fine-tuned for instruction following."
            echo "Excellent balance of performance and resource usage."
            echo ""
            echo "Recommended quantizations:"
            echo "- Q4_K_M: ~4GB RAM, good quality"
            echo "- Q5_K_M: ~5GB RAM, better quality"
            echo "- Q8_0: ~8GB RAM, near full quality"
            ;;
        "mixtral"|"mixtral-8x7b")
            print_header "Mixtral 8x7B"
            echo "A Mixture of Experts model with 8x7B parameters."
            echo "State-of-the-art performance but requires more resources."
            echo ""
            echo "Recommended quantizations:"
            echo "- Q4_K_M: ~26GB RAM, good for most uses"
            echo "- Q5_K_M: ~32GB RAM, better quality"
            ;;
        "codestral"|"codestral-22b")
            print_header "Codestral 22B"
            echo "A 22B parameter model specialized for code generation."
            echo "Excellent for programming tasks and code understanding."
            echo ""
            echo "Recommended quantizations:"
            echo "- Q4_K_M: ~13GB RAM, good for code completion"
            echo "- Q5_K_M: ~16GB RAM, better understanding"
            ;;
        *)
            print_error "Unknown model: $model"
            echo "Available models: mistral-7b, mixtral-8x7b, codestral-22b"
            ;;
    esac
}

# Function to check current models
check_models() {
    print_header "Current Models in $MISTRAL_MODELS_PATH"
    
    if [ ! -d "$MISTRAL_MODELS_PATH" ]; then
        print_info "Models directory does not exist yet"
        return
    fi
    
    local count=0
    while IFS= read -r -d '' file; do
        local size=$(du -h "$file" | cut -f1)
        local name=$(basename "$file")
        echo "- $name ($size)"
        ((count++))
    done < <(find "$MISTRAL_MODELS_PATH" -type f -name "*.gguf" -o -name "*.safetensors" -print0 2>/dev/null)
    
    if [ $count -eq 0 ]; then
        print_info "No models found"
        echo ""
        print_info "Use '$0 list-available' to see available models"
        print_info "Use '$0 download <url>' to download a model"
    else
        echo ""
        print_success "Found $count model(s)"
    fi
}

# Main script logic
case "${1:-help}" in
    list-available|list)
        list_available
        ;;
    download)
        if [ -z "${2:-}" ]; then
            print_error "URL required"
            echo "Usage: $0 download <url>"
            exit 1
        fi
        download_model "$2"
        ;;
    info)
        if [ -z "${2:-}" ]; then
            print_error "Model name required"
            echo "Usage: $0 info <model>"
            exit 1
        fi
        show_model_info "$2"
        ;;
    check)
        check_models
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        print_error "Unknown command: $1"
        usage
        exit 1
        ;;
esac