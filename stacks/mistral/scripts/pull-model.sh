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

# Helper function for cross-platform file size
get_file_size() {
    local file="$1"
    if command -v stat >/dev/null 2>&1; then
        # Try macOS format first, then Linux
        stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0"
    else
        # Fallback to ls
        ls -l "$file" 2>/dev/null | awk '{print $5}' || echo "0"
    fi
}

# Helper function to sanitize input for Docker commands
sanitize_docker_input() {
    local input="$1"
    # Remove potentially dangerous characters
    # Allow alphanumeric, dash, underscore, dot, slash, colon
    echo "$input" | sed 's/[^a-zA-Z0-9._/:@-]//g'
}

# Model registry mapping
declare -A MODEL_REGISTRY=(
    ["qwen2.5-coder:32b"]="Qwen/Qwen2.5-Coder-32B-Instruct"
    ["deepseek-coder:33b"]="deepseek-ai/deepseek-coder-33b-instruct"
    ["llama3:8b"]="meta-llama/Meta-Llama-3-8B-Instruct"
    ["mistral:7b"]="mistralai/Mistral-7B-Instruct-v0.2"
    ["mixtral:8x7b"]="mistralai/Mixtral-8x7B-Instruct-v0.1"
    ["codestral:22b"]="mistralai/Codestral-22B-v0.1"
    ["openhermes:7b"]="teknium/OpenHermes-2.5-Mistral-7B"
)

# Quantization levels
declare -A QUANTIZATION_MAP=(
    ["q4"]="q4_0"
    ["q4_k"]="q4_k_m"
    ["q5"]="q5_0"
    ["q5_k"]="q5_k_m"
    ["q8"]="q8_0"
    ["q8_0"]="q8_0"
    ["fp16"]="fp16"
)

# Default values
MODEL_NAME="${1:-}"
QUANTIZATION="${2:-q8_0}"
MISTRAL_MODELS_PATH="${MISTRAL_MODELS_PATH:-${ROOT_DIR}/data/mistral-models}"
MISTRAL_CONTAINER="${MISTRAL_CONTAINER:-frontier-mistral}"

# Function to show usage
usage() {
    cat << EOF
Mistral Model Pull Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    pull <model> [quantization]   Download a model from the registry
    list                         List available models in registry
    list-local                   List downloaded models
    help                        Show this help message

Arguments:
    model           Model name from registry (e.g., "qwen2.5-coder:32b")
    quantization    Quantization level (default: q8_0)
                   Options: q4, q4_k, q5, q5_k, q8, q8_0, fp16

Examples:
    $0 pull qwen2.5-coder:32b q4_k
    $0 pull mistral:7b
    $0 list
    $0 list-local

EOF
}

# Function to validate quantization
validate_quantization() {
    local quant="$1"
    if [[ -n "${QUANTIZATION_MAP[$quant]}" ]]; then
        echo "${QUANTIZATION_MAP[$quant]}"
    else
        print_error "Invalid quantization: $quant"
        print_info "Valid options: ${!QUANTIZATION_MAP[@]}"
        exit 1
    fi
}

# Function to check if mistral container is running
check_container() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${MISTRAL_CONTAINER}$"; then
        print_error "Mistral container '${MISTRAL_CONTAINER}' is not running"
        print_info "Please start the container with: cd ${MISTRAL_DIR} && docker-compose up -d"
        exit 1
    fi
}

# Function to download model using mistralrs
download_model() {
    local model_key="$1"
    local quantization="$2"
    
    # Get HuggingFace model ID from registry
    local hf_model="${MODEL_REGISTRY[$model_key]}"
    if [ -z "$hf_model" ]; then
        print_error "Unknown model: $model_key"
        print_info "Use '$0 list' to see available models"
        exit 1
    fi
    
    # Validate quantization
    local quant_value=$(validate_quantization "$quantization")
    
    # Check if model might require authentication
    if [[ "$hf_model" =~ ^(meta-llama|mistralai)/ ]]; then
        if [ -z "${HF_TOKEN:-}" ]; then
            print_warning "Model $hf_model may require authentication"
            print_info "Set HF_TOKEN environment variable if download fails"
        fi
    fi
    
    print_header "Downloading Model"
    print_info "Model: $model_key -> $hf_model"
    print_info "Quantization: $quantization -> $quant_value"
    print_info "Destination: $MISTRAL_MODELS_PATH"
    echo ""
    
    # Check if container is running
    check_container
    
    # Create models directory if it doesn't exist
    if [ ! -d "$MISTRAL_MODELS_PATH" ]; then
        print_info "Creating models directory: $MISTRAL_MODELS_PATH"
        mkdir -p "$MISTRAL_MODELS_PATH"
    fi
    
    # Download using mistralrs-server CLI in container
    print_info "Starting download..."
    
    # Build the command based on available mistralrs features
    # Note: The exact mistralrs-server download command may vary
    # This is a generic implementation that may need adjustment
    local download_cmd="docker exec -it ${MISTRAL_CONTAINER} mistralrs-server"
    
    # Try different download approaches based on mistralrs capabilities
    if docker exec ${MISTRAL_CONTAINER} mistralrs-server --help 2>/dev/null | grep -q "download"; then
        # If mistralrs has a download command
        local safe_hf_model=$(sanitize_docker_input "$hf_model")
        local safe_quant=$(sanitize_docker_input "$quant_value")
        docker exec -it ${MISTRAL_CONTAINER} mistralrs-server \
            download \
            --model-id "$safe_hf_model" \
            --quantization "$safe_quant" \
            --revision main \
            --output-dir /models
    else
        # Fallback: Use HuggingFace CLI if available in container
        print_info "Using HuggingFace CLI for download..."
        local hf_env=""
        if [ -n "${HF_TOKEN:-}" ]; then
            hf_env="HF_TOKEN='${HF_TOKEN}'"
        fi
        local safe_hf_model=$(sanitize_docker_input "$hf_model")
        local safe_model_key=$(sanitize_docker_input "${model_key//:/}")
        docker exec -it ${MISTRAL_CONTAINER} bash -c "
            $hf_env
            if command -v huggingface-cli >/dev/null 2>&1; then
                huggingface-cli download '$safe_hf_model' \
                    --local-dir '/models/$safe_model_key' \
                    --local-dir-use-symlinks False
            else
                echo 'Neither mistralrs download nor huggingface-cli is available'
                exit 1
            fi
        "
    fi
    
    if [ $? -eq 0 ]; then
        print_success "Model downloaded successfully!"
        
        # Create metadata file
        local metadata_file="${MISTRAL_MODELS_PATH}/${model_key//:/}.metadata.json"
        cat > "$metadata_file" << EOF
{
    "model_key": "$model_key",
    "huggingface_id": "$hf_model",
    "quantization": "$quant_value",
    "download_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "size_bytes": $(find "${MISTRAL_MODELS_PATH}" -name "${model_key//:/}*" -type f -print0 | while IFS= read -r -d '' file; do get_file_size "$file"; done | awk '{s+=$1} END {print s}' || echo 0)
}
EOF
        
        print_info "Metadata saved to: $metadata_file"
        echo ""
        print_info "To use this model in API requests:"
        echo "  \"model\": \"$model_key\""
    else
        print_error "Download failed"
        exit 1
    fi
}

# Function to list available models
list_models() {
    print_header "Available Models in Registry"
    echo ""
    
    # Sort models by key
    for model in $(echo "${!MODEL_REGISTRY[@]}" | tr ' ' '\n' | sort); do
        printf "%-25s -> %s\n" "$model" "${MODEL_REGISTRY[$model]}"
    done
    
    echo ""
    print_info "Available quantization levels: ${!QUANTIZATION_MAP[@]}"
    echo ""
    print_info "To download a model: $0 pull <model> [quantization]"
}

# Function to list local models
list_local_models() {
    print_header "Downloaded Models in $MISTRAL_MODELS_PATH"
    
    if [ ! -d "$MISTRAL_MODELS_PATH" ]; then
        print_info "Models directory does not exist yet"
        return
    fi
    
    local count=0
    
    # Look for metadata files
    while IFS= read -r -d '' metadata_file; do
        if [ -f "$metadata_file" ]; then
            local model_info=$(cat "$metadata_file" 2>/dev/null)
            if [ -n "$model_info" ]; then
                local model_key=$(echo "$model_info" | grep -o '"model_key"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
                local quantization=$(echo "$model_info" | grep -o '"quantization"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
                local size_bytes=$(echo "$model_info" | grep -o '"size_bytes"[[:space:]]*:[[:space:]]*[0-9]*' | awk '{print $NF}')
                local size_human=$(numfmt --to=iec-i --suffix=B "$size_bytes" 2>/dev/null || echo "${size_bytes}B")
                
                printf "%-25s %-10s %10s\n" "$model_key" "$quantization" "$size_human"
                ((count++))
            fi
        fi
    done < <(find "$MISTRAL_MODELS_PATH" -name "*.metadata.json" -print0 2>/dev/null)
    
    # Also check for GGUF files without metadata
    while IFS= read -r -d '' file; do
        local basename=$(basename "$file")
        if ! find "$MISTRAL_MODELS_PATH" -name "*.metadata.json" -print0 2>/dev/null | xargs -0 grep -l "$basename" >/dev/null 2>&1; then
            local size=$(du -h "$file" | cut -f1)
            printf "%-25s %-10s %10s (no metadata)\n" "$basename" "unknown" "$size"
            ((count++))
        fi
    done < <(find "$MISTRAL_MODELS_PATH" -type f \( -name "*.gguf" -o -name "*.safetensors" \) -print0 2>/dev/null)
    
    if [ $count -eq 0 ]; then
        print_info "No models found"
        echo ""
        print_info "Use '$0 list' to see available models"
        print_info "Use '$0 pull <model> [quantization]' to download a model"
    else
        echo ""
        print_success "Found $count model(s)"
    fi
}

# Main script logic
case "${1:-help}" in
    pull)
        if [ -z "$MODEL_NAME" ]; then
            print_error "Model name required"
            echo "Usage: $0 pull <model> [quantization]"
            exit 1
        fi
        download_model "$MODEL_NAME" "$QUANTIZATION"
        ;;
    list)
        list_models
        ;;
    list-local)
        list_local_models
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