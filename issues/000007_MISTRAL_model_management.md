# MISTRAL_000007: Implement Model Management for Mistral.rs

## Objective
Create scripts and utilities for downloading, converting, and managing models in Mistral.rs format, including support for GGUF and Hugging Face models.

## Context
Mistral.rs supports multiple model formats and sources. We need tooling to make model management as seamless as with Ollama, including downloading, conversion, and storage management.

## Tasks

### 1. Create Model Download Script
- Create `stacks/mistral/scripts/pull-model.sh`
- Support downloading from Hugging Face Hub
- Handle authentication tokens if required
- Show download progress and ETA

### 2. Implement Model Conversion Tools
- Add support for converting models to GGUF format
- Create quantization options (Q4, Q5, Q8)
- Preserve model metadata during conversion
- Validate converted models

### 3. Model Storage Management
- Create model listing script
- Implement model deletion functionality
- Add disk space checking
- Create model metadata tracking

### 4. Model Configuration
- Create model configuration templates
- Support for LoRA adapters
- Configure model-specific parameters
- Document supported models

## Implementation Details

```bash
#!/bin/bash
# stacks/mistral/scripts/pull-model.sh

set -e

MODEL_NAME="$1"
QUANTIZATION="${2:-q8_0}"

# Model registry mapping
declare -A MODEL_REGISTRY=(
    ["qwen2.5-coder:32b"]="Qwen/Qwen2.5-Coder-32B-Instruct"
    ["deepseek-coder:33b"]="deepseek-ai/deepseek-coder-33b-instruct"
    ["llama3:8b"]="meta-llama/Meta-Llama-3-8B-Instruct"
)

# Download model
download_model() {
    local hf_model="${MODEL_REGISTRY[$MODEL_NAME]}"
    if [ -z "$hf_model" ]; then
        echo "Unknown model: $MODEL_NAME"
        exit 1
    fi
    
    echo "Downloading $hf_model..."
    
    # Use huggingface-cli or mistralrs CLI
    docker exec frontier-mistral mistralrs-server \
        download \
        --model-id "$hf_model" \
        --quantization "$QUANTIZATION" \
        --revision main
}

# List available models
list_models() {
    echo "Available models:"
    for model in "${!MODEL_REGISTRY[@]}"; do
        echo "  - $model -> ${MODEL_REGISTRY[$model]}"
    done
}

# Main logic
case "${1:-help}" in
    list)
        list_models
        ;;
    *)
        download_model
        ;;
esac
```

## Success Criteria
- Models can be downloaded with simple commands
- Conversion process is automated and reliable
- Storage is efficiently managed
- Model compatibility is clearly documented

## Estimated Changes
- ~200 lines of shell scripts
- ~100 lines of model configuration
- Documentation updates