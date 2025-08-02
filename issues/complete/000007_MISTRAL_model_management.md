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

## Proposed Solution

After analyzing the existing codebase, I found that there's already a `download-model.sh` script that provides basic model downloading functionality. However, it needs enhancement to meet all the requirements in this issue. Here's my implementation plan:

1. **Enhance the existing download-model.sh**:
   - Add model registry mapping for easier model access
   - Integrate with mistralrs-server for proper model management
   - Add quantization options support
   - Improve progress tracking

2. **Create scripts directory and pull-model.sh**:
   - Create `stacks/mistral/scripts/` directory
   - Implement `pull-model.sh` that leverages mistralrs-server capabilities
   - Support the model registry mapping as specified in the issue
   - Add proper error handling and validation

3. **Add model conversion tools**:
   - Create `convert-model.sh` for GGUF conversion
   - Support multiple quantization levels (Q4, Q5, Q8)
   - Add model validation after conversion

4. **Implement storage management scripts**:
   - Create `list-models.sh` for listing models with metadata
   - Create `delete-model.sh` for safe model deletion
   - Add disk space checking functionality
   - Create model metadata JSON tracking

5. **Model configuration management**:
   - Create model configuration templates in `config/models/`
   - Add LoRA adapter support configuration
   - Document model-specific parameters
   - Create a supported models documentation

The solution will integrate with the existing Docker setup and use the mistralrs-server CLI where appropriate.

## Implementation Status

✅ **Completed all tasks:**

1. **Created Model Download Script** (`scripts/pull-model.sh`)
   - Implements model registry mapping as specified
   - Supports HuggingFace model downloads
   - Handles quantization options
   - Creates metadata files for tracking
   - Provides list and pull commands

2. **Implemented Model Conversion Tools** (`scripts/convert-model.sh`)
   - Supports GGUF format conversion
   - Multiple quantization levels (Q4, Q5, Q8, F16, F32)
   - Model validation after conversion
   - Metadata preservation
   - Progress tracking

3. **Model Storage Management**
   - `scripts/list-models.sh` - Lists models with detailed info, supports multiple output formats (detailed, simple, JSON)
   - `scripts/delete-model.sh` - Safe deletion with confirmation, metadata cleanup
   - `scripts/check-disk-space.sh` - Disk usage analysis and capacity estimation
   - Metadata tracking in JSON format

4. **Model Configuration**
   - Created configuration templates in `config/models/`
   - Specific configs for popular models (Mistral 7B, Qwen 2.5 Coder, Mixtral)
   - LoRA adapter template with full configuration options
   - `scripts/configure-model.sh` - Interactive model configuration tool
   - Created `SUPPORTED_MODELS.md` documentation

5. **Additional Features**
   - Test suite (`test-model-management.sh`) to verify functionality
   - Comprehensive error handling and validation
   - Color-coded output for better UX
   - Integration with existing Docker setup

All scripts are executable and follow the coding standards. The implementation provides a complete model management solution comparable to Ollama's functionality.