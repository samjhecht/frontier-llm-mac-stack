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
CYAN='\033[0;36m'
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
MISTRAL_MODELS_PATH="${MISTRAL_MODELS_PATH:-${ROOT_DIR}/data/mistral-models}"
FORMAT="${1:-detailed}"
SORT_BY="${2:-name}"

# Function to show usage
usage() {
    cat << EOF
Mistral Model List Tool

List all downloaded models with detailed information.

Usage: $0 [format] [sort]

Arguments:
    format      Output format (default: detailed)
                Options: detailed, simple, json
    sort        Sort by field (default: name)
                Options: name, size, date, type

Examples:
    $0                      # Detailed view sorted by name
    $0 simple              # Simple list
    $0 detailed size       # Detailed view sorted by size
    $0 json                # JSON output for scripting

EOF
}

# Function to format bytes to human readable
format_bytes() {
    local bytes="$1"
    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec-i --suffix=B "$bytes" 2>/dev/null || echo "${bytes}B"
    else
        # Fallback for systems without numfmt
        local units=("B" "KiB" "MiB" "GiB" "TiB")
        local unit=0
        local size=$bytes
        while [ "$size" -gt 1024 ] && [ "$unit" -lt 4 ]; do
            size=$((size / 1024))
            unit=$((unit + 1))
        done
        echo "${size}${units[$unit]}"
    fi
}

# Function to get model type from filename
get_model_type() {
    local filename="$1"
    case "${filename##*.}" in
        gguf) echo "GGUF" ;;
        safetensors) echo "SafeTensors" ;;
        bin) echo "Binary" ;;
        pth|pt) echo "PyTorch" ;;
        *) echo "Unknown" ;;
    esac
}

# Function to extract quantization from filename
extract_quantization() {
    local filename="$1"
    if [[ "$filename" =~ [qQ]([0-9]+)(_[0-9]+)?(_[kK](_[mM])?)? ]]; then
        echo "${BASH_REMATCH[0]}"
    elif [[ "$filename" =~ [fF](16|32) ]]; then
        echo "${BASH_REMATCH[0]}"
    else
        echo "unknown"
    fi
}

# Function to collect model information
collect_models() {
    local models=()
    
    if [ ! -d "$MISTRAL_MODELS_PATH" ]; then
        return
    fi
    
    # Find all model files
    while IFS= read -r -d '' file; do
        local basename=$(basename "$file")
        local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
        local mtime=$(stat -f%m "$file" 2>/dev/null || stat -c%Y "$file" 2>/dev/null || echo "0")
        local type=$(get_model_type "$basename")
        local quant=$(extract_quantization "$basename")
        
        # Check for metadata file
        local metadata_file="${file}.metadata.json"
        local has_metadata="no"
        local model_key=""
        local hf_id=""
        
        if [ -f "$metadata_file" ]; then
            has_metadata="yes"
            # Try jq first for proper JSON parsing
            if command -v jq >/dev/null 2>&1; then
                model_key=$(jq -r '.model_key // empty' "$metadata_file" 2>/dev/null || echo "")
                hf_id=$(jq -r '.huggingface_id // empty' "$metadata_file" 2>/dev/null || echo "")
                if [ -z "$quant" ] || [ "$quant" = "unknown" ]; then
                    quant=$(jq -r '.quantization // "unknown"' "$metadata_file" 2>/dev/null || echo "unknown")
                fi
            else
                # Fallback to grep/cut
                model_key=$(grep -o '"model_key"[[:space:]]*:[[:space:]]*"[^"]*"' "$metadata_file" 2>/dev/null | cut -d'"' -f4 || echo "")
                hf_id=$(grep -o '"huggingface_id"[[:space:]]*:[[:space:]]*"[^"]*"' "$metadata_file" 2>/dev/null | cut -d'"' -f4 || echo "")
                if [ -z "$quant" ] || [ "$quant" = "unknown" ]; then
                    quant=$(grep -o '"quantization"[[:space:]]*:[[:space:]]*"[^"]*"' "$metadata_file" 2>/dev/null | cut -d'"' -f4 || echo "unknown")
                fi
            fi
        fi
        
        # Store as tab-separated values
        models+=("${basename}	${size}	${mtime}	${type}	${quant}	${has_metadata}	${model_key}	${hf_id}")
    done < <(find "$MISTRAL_MODELS_PATH" -type f \( -name "*.gguf" -o -name "*.safetensors" -o -name "*.bin" -o -name "*.pth" -o -name "*.pt" \) ! -name "*.metadata.json" -print0 2>/dev/null)
    
    printf '%s\n' "${models[@]}"
}

# Function to display models in detailed format
display_detailed() {
    local models="$1"
    
    if [ -z "$models" ]; then
        print_info "No models found in $MISTRAL_MODELS_PATH"
        return
    fi
    
    print_header "Downloaded Models"
    echo ""
    
    # Header
    printf "%-40s %-12s %-10s %-12s %-10s %s\n" "Model Name" "Type" "Size" "Quantization" "Metadata" "HuggingFace ID"
    printf "%-40s %-12s %-10s %-12s %-10s %s\n" $(printf '%.0s-' {1..40}) $(printf '%.0s-' {1..12}) $(printf '%.0s-' {1..10}) $(printf '%.0s-' {1..12}) $(printf '%.0s-' {1..10}) $(printf '%.0s-' {1..30})
    
    local total_size=0
    local count=0
    
    while IFS=$'\t' read -r name size mtime type quant metadata model_key hf_id; do
        local size_human=$(format_bytes "$size")
        total_size=$((total_size + size))
        count=$((count + 1))
        
        # Truncate long names
        if [ ${#name} -gt 40 ]; then
            name="${name:0:37}..."
        fi
        
        # Color code by type
        case "$type" in
            GGUF) type_colored="${GREEN}${type}${NC}" ;;
            SafeTensors) type_colored="${CYAN}${type}${NC}" ;;
            *) type_colored="$type" ;;
        esac
        
        # Show HF ID or model key if available
        local display_id=""
        if [ -n "$hf_id" ]; then
            display_id="$hf_id"
        elif [ -n "$model_key" ]; then
            display_id="[$model_key]"
        fi
        if [ ${#display_id} -gt 30 ]; then
            display_id="${display_id:0:27}..."
        fi
        
        printf "%-40s %-12b %-10s %-12s %-10s %s\n" "$name" "$type_colored" "$size_human" "$quant" "$metadata" "$display_id"
    done <<< "$models"
    
    echo ""
    printf "%-40s %-12s %-10s\n" $(printf '%.0s-' {1..40}) $(printf '%.0s-' {1..12}) $(printf '%.0s-' {1..10})
    printf "%-40s %-12s %-10s\n" "Total: $count model(s)" "" "$(format_bytes $total_size)"
    
    # Disk usage info
    echo ""
    print_header "Disk Usage"
    if command -v df >/dev/null 2>&1; then
        local mount_point=$(df "$MISTRAL_MODELS_PATH" 2>/dev/null | tail -1 | awk '{print $NF}')
        local available=$(df -h "$MISTRAL_MODELS_PATH" 2>/dev/null | tail -1 | awk '{print $4}')
        print_info "Models directory: $MISTRAL_MODELS_PATH"
        print_info "Available space: $available on $mount_point"
    fi
}

# Function to display models in simple format
display_simple() {
    local models="$1"
    
    if [ -z "$models" ]; then
        print_info "No models found"
        return
    fi
    
    while IFS=$'\t' read -r name size mtime type quant metadata model_key hf_id; do
        echo "$name"
    done <<< "$models"
}

# Function to display models in JSON format
display_json() {
    local models="$1"
    
    echo "{"
    echo "  \"models_directory\": \"$MISTRAL_MODELS_PATH\","
    echo "  \"models\": ["
    
    local first=true
    while IFS=$'\t' read -r name size mtime type quant metadata model_key hf_id; do
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi
        
        cat << EOF
    {
      "filename": "$name",
      "size_bytes": $size,
      "size_human": "$(format_bytes $size)",
      "modified_timestamp": $mtime,
      "modified_date": "$(date -r $mtime -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")",
      "type": "$type",
      "quantization": "$quant",
      "has_metadata": $([ "$metadata" = "yes" ] && echo "true" || echo "false"),
      "model_key": $([ -n "$model_key" ] && echo "\"$model_key\"" || echo "null"),
      "huggingface_id": $([ -n "$hf_id" ] && echo "\"$hf_id\"" || echo "null")
    }
EOF
    done <<< "$models"
    
    echo "  ]"
    echo "}"
}

# Function to sort models
sort_models() {
    local models="$1"
    local sort_by="$2"
    
    case "$sort_by" in
        size)
            # Sort by size (numeric, descending)
            echo "$models" | sort -t$'\t' -k2 -nr
            ;;
        date|mtime)
            # Sort by modification time (numeric, descending)
            echo "$models" | sort -t$'\t' -k3 -nr
            ;;
        type)
            # Sort by type, then name
            echo "$models" | sort -t$'\t' -k4,4 -k1,1
            ;;
        name|*)
            # Sort by name (default)
            echo "$models" | sort -t$'\t' -k1
            ;;
    esac
}

# Main script logic
case "${1:-detailed}" in
    help|--help|-h)
        usage
        exit 0
        ;;
    detailed|simple|json)
        # Valid format
        ;;
    *)
        print_error "Invalid format: $1"
        usage
        exit 1
        ;;
esac

# Collect and sort models
models=$(collect_models)
if [ -n "$models" ]; then
    models=$(sort_models "$models" "$SORT_BY")
fi

# Display based on format
case "$FORMAT" in
    detailed)
        display_detailed "$models"
        ;;
    simple)
        display_simple "$models"
        ;;
    json)
        display_json "$models"
        ;;
esac