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

# Load environment variables
if [ -f "${MISTRAL_DIR}/.env" ]; then
    source "${MISTRAL_DIR}/.env"
elif [ -f "${ROOT_DIR}/.env" ]; then
    source "${ROOT_DIR}/.env"
fi

# Default values
INPUT_MODEL="${1:-}"
OUTPUT_FORMAT="${2:-gguf}"
QUANTIZATION="${3:-q8_0}"
MISTRAL_MODELS_PATH="${MISTRAL_MODELS_PATH:-${ROOT_DIR}/data/mistral-models}"
MISTRAL_CONTAINER="${MISTRAL_CONTAINER:-frontier-mistral}"

# Supported quantization levels
declare -A QUANTIZATION_LEVELS=(
    ["q4_0"]="4-bit quantization (smallest size, lowest quality)"
    ["q4_k_m"]="4-bit quantization with k-means (good balance)"
    ["q5_0"]="5-bit quantization"
    ["q5_k_m"]="5-bit quantization with k-means (better quality)"
    ["q8_0"]="8-bit quantization (near full quality)"
    ["f16"]="16-bit float (full quality, large size)"
    ["f32"]="32-bit float (original quality, largest size)"
)

# Function to show usage
usage() {
    cat << EOF
Mistral Model Conversion Tool

Convert models between different formats and quantization levels.

Usage: $0 <input_model> [output_format] [quantization]

Arguments:
    input_model     Path to input model file or model name
    output_format   Target format (default: gguf)
                   Options: gguf, safetensors
    quantization    Quantization level (default: q8_0)
                   Options: q4_0, q4_k_m, q5_0, q5_k_m, q8_0, f16, f32

Examples:
    $0 model.safetensors gguf q4_k_m
    $0 /path/to/model.bin gguf q8_0
    $0 mistral-7b gguf q5_k_m

Quantization Levels:
EOF
    for quant in "${!QUANTIZATION_LEVELS[@]}"; do
        printf "  %-10s %s\n" "$quant" "${QUANTIZATION_LEVELS[$quant]}"
    done | sort
}

# Function to validate quantization level
validate_quantization() {
    local quant="$1"
    if [[ -z "${QUANTIZATION_LEVELS[$quant]}" ]]; then
        print_error "Invalid quantization level: $quant"
        print_info "Valid options: ${!QUANTIZATION_LEVELS[@]}"
        exit 1
    fi
}

# Function to check if container is running
check_container() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${MISTRAL_CONTAINER}$"; then
        print_error "Mistral container '${MISTRAL_CONTAINER}' is not running"
        print_info "Please start the container with: cd ${MISTRAL_DIR} && docker-compose up -d"
        exit 1
    fi
}

# Function to get model file path
get_model_path() {
    local model="$1"
    
    # If it's already a path, return it
    if [[ "$model" == /* ]] || [[ -f "$model" ]]; then
        echo "$model"
        return
    fi
    
    # Look in models directory
    if [ -d "$MISTRAL_MODELS_PATH" ]; then
        # Try exact match first
        if [ -f "${MISTRAL_MODELS_PATH}/${model}" ]; then
            echo "${MISTRAL_MODELS_PATH}/${model}"
            return
        fi
        
        # Try with common extensions
        for ext in ".gguf" ".safetensors" ".bin" ".pth"; do
            if [ -f "${MISTRAL_MODELS_PATH}/${model}${ext}" ]; then
                echo "${MISTRAL_MODELS_PATH}/${model}${ext}"
                return
            fi
        done
        
        # Try pattern match
        local found=$(find "$MISTRAL_MODELS_PATH" -name "*${model}*" -type f | head -1)
        if [ -n "$found" ]; then
            echo "$found"
            return
        fi
    fi
    
    # Not found
    echo ""
}

# Function to validate model file
validate_model_file() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        print_error "Model file not found: $file"
        exit 1
    fi
    
    # Check file size
    local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
    if [ "$size" -lt 1000000 ]; then  # Less than 1MB
        print_error "Model file seems too small (${size} bytes)"
        exit 1
    fi
    
    # Check file type
    local ext="${file##*.}"
    case "$ext" in
        gguf|safetensors|bin|pth|pt)
            return 0
            ;;
        *)
            print_error "Unsupported file extension: .$ext"
            print_info "Supported formats: .gguf, .safetensors, .bin, .pth, .pt"
            exit 1
            ;;
    esac
}

# Function to convert model
convert_model() {
    local input_file="$1"
    local output_format="$2"
    local quantization="$3"
    
    # Validate inputs
    validate_model_file "$input_file"
    validate_quantization "$quantization"
    
    # Check container
    check_container
    
    # Generate output filename
    local input_basename=$(basename "$input_file")
    local input_name="${input_basename%.*}"
    local output_file="${MISTRAL_MODELS_PATH}/${input_name}-${quantization}.${output_format}"
    
    print_header "Model Conversion"
    print_info "Input: $input_file"
    print_info "Output: $output_file"
    print_info "Format: $output_format"
    print_info "Quantization: $quantization (${QUANTIZATION_LEVELS[$quantization]})"
    echo ""
    
    # Create output directory if needed
    mkdir -p "$(dirname "$output_file")"
    
    # Perform conversion based on format
    case "$output_format" in
        gguf)
            convert_to_gguf "$input_file" "$output_file" "$quantization"
            ;;
        safetensors)
            convert_to_safetensors "$input_file" "$output_file" "$quantization"
            ;;
        *)
            print_error "Unsupported output format: $output_format"
            exit 1
            ;;
    esac
    
    if [ $? -eq 0 ] && [ -f "$output_file" ]; then
        print_success "Conversion completed successfully!"
        
        # Validate output
        validate_converted_model "$output_file"
        
        # Show file info
        local size=$(du -h "$output_file" | cut -f1)
        print_info "Output file size: $size"
        
        # Create metadata
        create_conversion_metadata "$input_file" "$output_file" "$quantization"
    else
        print_error "Conversion failed"
        exit 1
    fi
}

# Function to convert to GGUF format
convert_to_gguf() {
    local input="$1"
    local output="$2"
    local quant="$3"
    
    print_info "Converting to GGUF format..."
    
    # Copy input to container if needed
    local container_input="/tmp/$(basename "$input")"
    docker cp "$input" "${MISTRAL_CONTAINER}:${container_input}"
    
    # Try using llama.cpp convert script if available
    docker exec -it ${MISTRAL_CONTAINER} bash -c "
        if [ -f /opt/llama.cpp/convert.py ]; then
            python /opt/llama.cpp/convert.py $container_input --outtype ${quant} --outfile /models/$(basename "$output")
        elif command -v convert-to-gguf >/dev/null 2>&1; then
            convert-to-gguf $container_input /models/$(basename "$output") --quantization ${quant}
        else
            echo 'No GGUF conversion tool available in container'
            exit 1
        fi
    "
    
    # Clean up
    docker exec ${MISTRAL_CONTAINER} rm -f "$container_input"
}

# Function to convert to SafeTensors format
convert_to_safetensors() {
    local input="$1"
    local output="$2"
    local quant="$3"
    
    print_info "Converting to SafeTensors format..."
    
    # This would require appropriate conversion tools in the container
    # For now, this is a placeholder implementation
    docker exec -it ${MISTRAL_CONTAINER} bash -c "
        if command -v convert-to-safetensors >/dev/null 2>&1; then
            convert-to-safetensors /models/$(basename "$input") /models/$(basename "$output") --quantization ${quant}
        else
            echo 'SafeTensors conversion not yet implemented'
            exit 1
        fi
    "
}

# Function to validate converted model
validate_converted_model() {
    local model_file="$1"
    
    print_info "Validating converted model..."
    
    # Basic validation - check file exists and has reasonable size
    if [ ! -f "$model_file" ]; then
        print_error "Output file not created"
        return 1
    fi
    
    local size=$(stat -f%z "$model_file" 2>/dev/null || stat -c%s "$model_file" 2>/dev/null || echo "0")
    if [ "$size" -lt 1000000 ]; then
        print_error "Output file is too small (${size} bytes)"
        return 1
    fi
    
    # Format-specific validation
    local ext="${model_file##*.}"
    case "$ext" in
        gguf)
            # Check GGUF header
            if ! xxd -l 4 "$model_file" 2>/dev/null | grep -q "GGUF"; then
                print_error "Invalid GGUF file format"
                return 1
            fi
            ;;
    esac
    
    print_success "Model validation passed"
    return 0
}

# Function to create conversion metadata
create_conversion_metadata() {
    local input_file="$1"
    local output_file="$2"
    local quantization="$3"
    
    local metadata_file="${output_file}.metadata.json"
    local input_size=$(stat -f%z "$input_file" 2>/dev/null || stat -c%s "$input_file" 2>/dev/null || echo "0")
    local output_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo "0")
    
    cat > "$metadata_file" << EOF
{
    "source_file": "$(basename "$input_file")",
    "source_size_bytes": $input_size,
    "output_file": "$(basename "$output_file")",
    "output_size_bytes": $output_size,
    "quantization": "$quantization",
    "compression_ratio": $(awk "BEGIN {printf \"%.2f\", $input_size/$output_size}"),
    "conversion_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "format": "${output_file##*.}"
}
EOF
    
    print_info "Metadata saved to: $metadata_file"
}

# Main script logic
if [ -z "$INPUT_MODEL" ]; then
    usage
    exit 1
fi

# Get full path to model
MODEL_PATH=$(get_model_path "$INPUT_MODEL")
if [ -z "$MODEL_PATH" ]; then
    print_error "Model not found: $INPUT_MODEL"
    print_info "Please provide a valid model file path or name"
    exit 1
fi

# Convert the model
convert_model "$MODEL_PATH" "$OUTPUT_FORMAT" "$QUANTIZATION"