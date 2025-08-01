#!/bin/bash

# Frontier LLM Stack - Model Pull Script

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
print_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

print_info() {
    echo -e "${YELLOW}INFO: $1${NC}"
}

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    print_error "docker-compose is not installed or not in PATH"
    exit 1
fi

# Check if a stack is selected
if [ ! -f ".current-stack" ]; then
    print_error "No stack selected. Please run './stack-select.sh select <stack>' first."
    exit 1
fi

CURRENT_STACK=$(cat .current-stack)

# Load environment variables if .env exists
if [ -f ".env" ]; then
    source .env
fi

# Default model if not specified
DEFAULT_MODEL="${DEFAULT_MODEL:-qwen2.5-coder:32b-instruct-q8_0}"

# Model name from argument or default
MODEL="${1:-$DEFAULT_MODEL}"

# Validate model name
if [[ -z "$MODEL" ]]; then
    print_error "Model name cannot be empty"
    exit 1
fi

print_info "Pulling model: ${MODEL} for ${CURRENT_STACK} stack..."

case "$CURRENT_STACK" in
    ollama)
        # Check if docker-compose-wrapper.sh exists and is executable
        if [[ ! -x "./docker-compose-wrapper.sh" ]]; then
            print_error "docker-compose-wrapper.sh not found or not executable"
            exit 1
        fi
        
        # Check if Ollama is running
        if ! ./docker-compose-wrapper.sh ps 2>/dev/null | grep -q "frontier-ollama.*Up"; then
            print_error "Ollama service is not running. Please run './start.sh' first."
            exit 1
        fi
        
        # Check if Ollama is healthy
        print_info "Checking Ollama health status..."
        if ! ./docker-compose-wrapper.sh exec -T ollama curl -f http://localhost:11434/api/version >/dev/null 2>&1; then
            print_error "Ollama service is not healthy"
            exit 1
        fi
        
        # Pull the model using Ollama API
        print_info "Pulling model via Ollama API (this may take a while)..."
        if ./docker-compose-wrapper.sh exec -T ollama ollama pull "${MODEL}"; then
            print_success "Model '${MODEL}' pulled successfully!"
            
            # List available models
            echo ""
            print_info "Available models:"
            if ./docker-compose-wrapper.sh exec -T ollama ollama list; then
                echo ""
            else
                print_warning "Could not list models"
            fi
        else
            print_error "Failed to pull model '${MODEL}'"
            print_info "Please check if the model name is correct and try again"
            exit 1
        fi
        ;;
        
    mistral)
        print_warning "Mistral stack does not support automatic model pulling"
        print_info "To use models with Mistral, follow these steps:"
        echo "1. Download model files to: ${MISTRAL_MODELS_PATH:-./data/mistral-models}"
        echo "2. Ensure models are in a format compatible with mistral.rs"
        echo "3. Configure the model path in your Mistral settings"
        echo ""
        print_info "Supported model formats: GGUF, SafeTensors"
        print_info "See https://github.com/EricLBuehler/mistral.rs for more information"
        exit 0
        ;;
        
    *)
        print_error "Unknown stack '${CURRENT_STACK}'"
        print_info "Available stacks: ollama, mistral"
        exit 1
        ;;
esac