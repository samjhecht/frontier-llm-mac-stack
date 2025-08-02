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

# Helper function to sanitize input for Docker commands
sanitize_docker_input() {
    local input="$1"
    # Remove potentially dangerous characters
    # Allow alphanumeric, dash, underscore, dot, slash, colon
    echo "$input" | sed 's/[^a-zA-Z0-9._/:@-]//g'
}

# Default values
MODEL_NAME=""
FORCE="no"
DRY_RUN="no"
MISTRAL_MODELS_PATH="${MISTRAL_MODELS_PATH:-${ROOT_DIR}/data/mistral-models}"
MISTRAL_CONTAINER="${MISTRAL_CONTAINER:-frontier-mistral}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN="yes"
            shift
            ;;
        --force|-f)
            FORCE="yes"
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            if [ -z "$MODEL_NAME" ]; then
                MODEL_NAME="$1"
            fi
            shift
            ;;
    esac
done

# Function to show usage
usage() {
    cat << EOF
Mistral Model Delete Tool

Safely delete downloaded models and their metadata.

Usage: $0 [options] <model>

Options:
    --dry-run      Show what would be deleted without actually deleting
    --force, -f    Skip confirmation prompt
    --help, -h     Show this help message

Arguments:
    model          Model filename or pattern to delete

Examples:
    $0 mistral-7b-instruct-v0.2.Q4_K_M.gguf
    $0 --dry-run "mistral-7b*"                 # Preview what would be deleted
    $0 --force qwen2.5-coder:32b               # Force delete without prompt

Safety Features:
    - Confirmation prompt before deletion (unless forced)
    - Shows all files that will be deleted
    - Removes associated metadata files
    - Checks if model is currently in use

EOF
}

# Function to format bytes
format_bytes() {
    local bytes="$1"
    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec-i --suffix=B "$bytes" 2>/dev/null || echo "${bytes}B"
    else
        echo "${bytes} bytes"
    fi
}

# Function to find model files
find_model_files() {
    local pattern="$1"
    local files=()
    
    if [ ! -d "$MISTRAL_MODELS_PATH" ]; then
        return
    fi
    
    # Direct file match
    if [ -f "${MISTRAL_MODELS_PATH}/${pattern}" ]; then
        files+=("${MISTRAL_MODELS_PATH}/${pattern}")
        # Check for metadata file
        if [ -f "${MISTRAL_MODELS_PATH}/${pattern}.metadata.json" ]; then
            files+=("${MISTRAL_MODELS_PATH}/${pattern}.metadata.json")
        fi
    else
        # Pattern match
        while IFS= read -r -d '' file; do
            files+=("$file")
            # Check for metadata file
            if [ -f "${file}.metadata.json" ]; then
                files+=("${file}.metadata.json")
            fi
        done < <(find "$MISTRAL_MODELS_PATH" -name "$pattern" -type f -print0 2>/dev/null)
    fi
    
    # Remove duplicates
    printf '%s\n' "${files[@]}" | sort -u
}

# Function to check if model is in use
check_model_in_use() {
    local model_file="$1"
    local basename=$(basename "$model_file")
    
    # Check if any mistral container is running and using this model
    if docker ps --format '{{.Names}}' | grep -q "mistral"; then
        # Check container logs or process list for model usage
        # This is a simplified check - in production you'd want more robust checking
        local safe_basename=$(sanitize_docker_input "$basename")
        if docker exec ${MISTRAL_CONTAINER} ps aux 2>/dev/null | grep -q "$safe_basename"; then
            return 0  # Model is in use
        fi
    fi
    
    return 1  # Model is not in use
}

# Function to delete model
delete_model() {
    local pattern="$1"
    local force="$2"
    
    print_header "Finding Models to Delete"
    
    # Find all matching files
    local files_to_delete=()
    while IFS= read -r file; do
        files_to_delete+=("$file")
    done < <(find_model_files "$pattern")
    
    if [ ${#files_to_delete[@]} -eq 0 ]; then
        print_error "No models found matching: $pattern"
        return 1
    fi
    
    # Display files to be deleted
    echo ""
    print_info "The following files will be deleted:"
    local total_size=0
    for file in "${files_to_delete[@]}"; do
        if [ -f "$file" ]; then
            local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
            total_size=$((total_size + size))
            local size_human=$(format_bytes "$size")
            local basename=$(basename "$file")
            if [[ "$basename" == *.metadata.json ]]; then
                echo "  - [metadata] $basename ($size_human)"
            else
                echo "  - $basename ($size_human)"
                # Check if in use
                if check_model_in_use "$file"; then
                    print_warning "    Model appears to be in use!"
                fi
            fi
        fi
    done
    
    echo ""
    print_info "Total size to be freed: $(format_bytes $total_size)"
    echo ""
    
    # Confirmation prompt
    if [ "$force" != "yes" ] && [ "$DRY_RUN" != "yes" ]; then
        read -p "Are you sure you want to delete these files? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Deletion cancelled"
            return 0
        fi
    fi
    
    if [ "$DRY_RUN" = "yes" ]; then
        print_info "DRY RUN: No files will be deleted"
        echo ""
        print_success "Would delete $file_count file(s)"
        print_info "Would free $(format_bytes $total_size) of disk space"
    else
        # Perform deletion
        print_info "Deleting files..."
        local deleted_count=0
        local failed_count=0
        
        for file in "${files_to_delete[@]}"; do
            if [ -f "$file" ]; then
                if rm -f "$file" 2>/dev/null; then
                    ((deleted_count++))
                    echo "  ✓ Deleted: $(basename "$file")"
                else
                    ((failed_count++))
                    print_error "  ✗ Failed to delete: $(basename "$file")"
                fi
            fi
        done
        
        echo ""
        if [ $failed_count -eq 0 ]; then
            print_success "Successfully deleted $deleted_count file(s)"
            print_info "Freed $(format_bytes $total_size) of disk space"
        else
            print_warning "Deleted $deleted_count file(s), failed to delete $failed_count file(s)"
        fi
        
        # Clean up empty directories
        if [ -d "$MISTRAL_MODELS_PATH" ]; then
            find "$MISTRAL_MODELS_PATH" -type d -empty -delete 2>/dev/null || true
        fi
    fi
}

# Function to list models before deletion
list_available_models() {
    print_header "Available Models"
    
    if [ ! -d "$MISTRAL_MODELS_PATH" ]; then
        print_info "No models directory found"
        return
    fi
    
    local count=0
    while IFS= read -r -d '' file; do
        local basename=$(basename "$file")
        local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
        local size_human=$(format_bytes "$size")
        echo "  - $basename ($size_human)"
        ((count++))
    done < <(find "$MISTRAL_MODELS_PATH" -type f \( -name "*.gguf" -o -name "*.safetensors" -o -name "*.bin" \) -print0 2>/dev/null)
    
    if [ $count -eq 0 ]; then
        print_info "No models found"
    else
        echo ""
        print_info "Found $count model(s)"
    fi
}

# Main script logic
if [ -z "$MODEL_NAME" ]; then
    print_error "Model name or pattern required"
    echo ""
    list_available_models
    echo ""
    usage
    exit 1
fi

# Handle help
case "$MODEL_NAME" in
    help|--help|-h)
        usage
        exit 0
        ;;
esac

# Delete the model
delete_model "$MODEL_NAME" "$FORCE"