#!/bin/bash

# Frontier LLM Stack - Model Pull Script

set -e

# Default model if not specified
DEFAULT_MODEL="${DEFAULT_MODEL:-qwen2.5-coder:32b-instruct-q8_0}"

# Check if a stack is selected
if [ ! -f ".current-stack" ]; then
    echo "Error: No stack selected. Please run './stack-select.sh select <stack>' first."
    exit 1
fi

CURRENT_STACK=$(cat .current-stack)

# Model name from argument or default
MODEL="${1:-$DEFAULT_MODEL}"

echo "Pulling model: ${MODEL} for ${CURRENT_STACK} stack..."

case "$CURRENT_STACK" in
    ollama)
        # Check if Ollama is running
        if ! ./docker-compose-wrapper.sh ps | grep -q "frontier-ollama.*Up"; then
            echo "Error: Ollama service is not running. Please run './start.sh' first."
            exit 1
        fi
        
        # Pull the model using Ollama API
        echo "Pulling model via Ollama API..."
        ./docker-compose-wrapper.sh exec ollama ollama pull "${MODEL}"
        
        echo ""
        echo "Model pulled successfully!"
        echo "Available models:"
        ./docker-compose-wrapper.sh exec ollama ollama list
        ;;
        
    mistral)
        echo "Warning: Mistral stack model pulling not yet implemented"
        echo "Please manually download models to the configured models directory"
        ;;
        
    *)
        echo "Error: Unknown stack '${CURRENT_STACK}'"
        exit 1
        ;;
esac