# Supported Models for Mistral.rs

This document lists the models that have been tested and configured for use with the Mistral.rs stack.

## Model Registry

The following models are available through the `pull-model.sh` script:

| Model ID | HuggingFace Repository | Size | Context | Use Case |
|----------|----------------------|------|---------|----------|
| `mistral:7b` | mistralai/Mistral-7B-Instruct-v0.2 | 7B | 32K | General purpose |
| `mixtral:8x7b` | mistralai/Mixtral-8x7B-Instruct-v0.1 | 8x7B | 32K | Advanced reasoning |
| `qwen2.5-coder:32b` | Qwen/Qwen2.5-Coder-32B-Instruct | 32B | 128K | Code generation |
| `deepseek-coder:33b` | deepseek-ai/deepseek-coder-33b-instruct | 33B | 16K | Code completion |
| `llama3:8b` | meta-llama/Meta-Llama-3-8B-Instruct | 8B | 8K | General chat |
| `codestral:22b` | mistralai/Codestral-22B-v0.1 | 22B | 32K | Code assistance |
| `openhermes:7b` | teknium/OpenHermes-2.5-Mistral-7B | 7B | 32K | Instruction following |

## Quantization Options

All models support the following quantization levels:

- **q4_0**: 4-bit quantization (smallest size, ~3-4GB for 7B models)
- **q4_k_m**: 4-bit with k-means optimization (recommended for most users)
- **q5_0**: 5-bit quantization 
- **q5_k_m**: 5-bit with k-means optimization
- **q8_0**: 8-bit quantization (near full quality)
- **f16**: 16-bit floating point (full quality, large size)
- **f32**: 32-bit floating point (original quality, largest size)

## Model Configuration

Each model has a corresponding configuration file in `config/models/`. These files control:

- Inference parameters (temperature, top_p, etc.)
- Prompt templates
- Memory settings
- GPU acceleration options
- LoRA adapter support

## Downloading Models

### Using the Model Registry

```bash
# Download with default quantization (q8_0)
./scripts/pull-model.sh mistral:7b

# Download with specific quantization
./scripts/pull-model.sh qwen2.5-coder:32b q4_k
```

### Direct Download

```bash
# Download from HuggingFace URL
./download-model.sh https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.2-GGUF/resolve/main/mistral-7b-instruct-v0.2.Q4_K_M.gguf
```

## Model Management

### List Models

```bash
# List downloaded models
./scripts/list-models.sh

# Simple list
./scripts/list-models.sh simple

# JSON output
./scripts/list-models.sh json
```

### Delete Models

```bash
# Delete specific model
./scripts/delete-model.sh mistral-7b-instruct-v0.2.Q4_K_M.gguf

# Delete with pattern
./scripts/delete-model.sh "mistral-7b*"
```

### Check Disk Space

```bash
# Check available space
./scripts/check-disk-space.sh

# Check for specific minimum (e.g., 50GB)
./scripts/check-disk-space.sh 50
```

## Model Conversion

Convert between formats and quantization levels:

```bash
# Convert to GGUF with Q4 quantization
./scripts/convert-model.sh model.safetensors gguf q4_k_m

# Convert with Q8 quantization
./scripts/convert-model.sh model.bin gguf q8_0
```

## LoRA Adapters

LoRA (Low-Rank Adaptation) allows fine-tuning models for specific tasks:

1. Place adapter files in the models directory
2. Configure the adapter using the template in `config/models/lora-adapter-template.toml`
3. Reference the adapter in your model configuration

## Memory Requirements

Approximate memory requirements by model size and quantization:

| Model Size | Q4 | Q5 | Q8 | F16 |
|------------|-----|-----|-----|------|
| 7B | 4GB | 5GB | 8GB | 14GB |
| 13B | 8GB | 10GB | 16GB | 26GB |
| 32B | 20GB | 25GB | 40GB | 64GB |
| 70B | 40GB | 50GB | 80GB | 140GB |

## GPU Acceleration

All models support GPU acceleration through:
- CUDA (NVIDIA GPUs)
- Metal (Apple Silicon)
- ROCm (AMD GPUs)

Configure GPU usage in the model's `.toml` file:
```toml
[inference]
use_gpu = true
gpu_layers = -1  # Use all layers on GPU
```

## Troubleshooting

### Model Download Issues

1. **Authentication Required**: Some models require HuggingFace login
   ```bash
   export HF_TOKEN=your_token_here
   ```

2. **Insufficient Space**: Check disk space before downloading
   ```bash
   ./scripts/check-disk-space.sh
   ```

3. **Slow Downloads**: Use a download manager or mirror

### Model Loading Issues

1. **Out of Memory**: Use smaller quantization or reduce context length
2. **Unsupported Format**: Ensure model is in GGUF or SafeTensors format
3. **GPU Errors**: Check GPU drivers and CUDA/Metal installation

## Adding New Models

To add support for a new model:

1. Add entry to `MODEL_REGISTRY` in `scripts/pull-model.sh`
2. Create configuration file in `config/models/`
3. Test model loading and inference
4. Update this documentation

## Performance Tips

1. **Quantization**: Use Q4_K_M for best size/quality balance
2. **GPU Layers**: Offload as many layers as GPU memory allows
3. **Batch Size**: Adjust based on available memory
4. **Context Length**: Reduce if experiencing OOM errors
5. **Flash Attention**: Enable for faster inference on supported models