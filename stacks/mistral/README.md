# Mistral.rs Stack

This directory contains the Docker Compose configuration for running Mistral.rs inference server as part of the Frontier LLM Stack.

## Quick Start

1. Copy the environment file:
   ```bash
   cp .env.example .env
   ```

2. Download a model:
   ```bash
   ./download-model.sh list-available
   ./download-model.sh download <model-url>
   ```

3. Start the service:
   ```bash
   ../../scripts/mistral-start.sh
   ```

## Configuration

### Environment Variables

Key environment variables (configured in `.env`):

- `MISTRAL_API_PORT`: API port (default: 8080)
- `MISTRAL_MODELS_PATH`: Path to models directory
- `MISTRAL_MEMORY_LIMIT`: Memory limit (default: 64G)
- `MISTRAL_MEMORY_RESERVATION`: Memory reservation (default: 32G)
- `MISTRAL_LOG_LEVEL`: Log level (default: info)
- `MISTRAL_MAX_BATCH_SIZE`: Maximum batch size (default: 8)
- `MISTRAL_MODEL_TYPE`: Model type - plain, gguf, lora, x-lora, toml (default: plain)
- `MISTRAL_MODEL_ID`: Model identifier for Hugging Face models
- `ENABLE_METAL`: Enable Metal acceleration on macOS (default: true)
- `ENABLE_CUDA`: Enable CUDA acceleration on NVIDIA GPUs (default: false)

### Platform-Specific Configuration

The service automatically detects your platform and configures acceleration:

- **macOS**: Uses Metal acceleration by default
- **Linux with NVIDIA GPU**: Uses CUDA acceleration via docker-compose.cuda.yml
- **Other**: Falls back to CPU mode

### Networks

The Mistral service connects to two networks:
- `frontier-llm-network`: Main network for LLM services
- `frontier-monitoring`: Monitoring infrastructure network

### Health Check

The service includes a health check endpoint at `/health` that verifies the server is running properly.

## Management Scripts

- `../../scripts/mistral-start.sh`: Start the Mistral service
- `../../scripts/mistral-stop.sh`: Stop the Mistral service
- `../../scripts/mistral-status.sh`: Check service status and health

## Model Management

Use the included `download-model.sh` script to download compatible models:

```bash
# List available models
./download-model.sh list-available

# Download a specific model
./download-model.sh download <url>

# Check downloaded models
./download-model.sh check
```

## API Endpoints

### Native Mistral.rs API (OpenAI-compatible)

- Health: `http://localhost:8080/health`
- Models: `http://localhost:8080/v1/models`
- Chat Completions: `http://localhost:8080/v1/chat/completions`

### Ollama API Compatibility Layer

The Mistral stack includes an Ollama API compatibility layer for tools expecting Ollama's API format (e.g., Aider). The proxy runs on port 11434 by default.

#### Endpoints

- Health: `http://localhost:11434/`
- Version: `http://localhost:11434/api/version`
- List Models: `http://localhost:11434/api/tags`
- Generate: `http://localhost:11434/api/generate`
- Chat: `http://localhost:11434/api/chat`

#### Using with Aider

To use Mistral.rs with Aider through the Ollama compatibility layer:

```bash
export OLLAMA_API_BASE=http://localhost:11434
aider --model mistral:latest
```

#### Testing Compatibility

Run the included test script to verify the API compatibility:

```bash
./test-aider-compatibility.sh
```

#### Model Name Mapping

The compatibility layer automatically maps between Ollama and Mistral.rs model names:

- `mistral:latest` → `mistral-7b`
- `mistral:7b` → `mistral-7b`
- `mixtral:latest` → `mixtral-8x7b`
- `mixtral:8x7b` → `mixtral-8x7b`

#### Configuration

The proxy can be configured via environment variables in `.env`:

- `OLLAMA_API_PORT`: Port for Ollama API compatibility (default: 11434)
- `PROXY_LOG_LEVEL`: Log level for the proxy (default: info)

## Performance Optimization

### Mac Studio Optimization

The Mistral stack includes comprehensive performance optimizations for Mac Studio hardware:

1. **Metal Acceleration**: Automatic detection and configuration of Metal GPU acceleration
2. **Memory Management**: Optimized memory pooling and caching for large models
3. **Inference Optimization**: Flash attention, continuous batching, and prefix caching
4. **Quantization**: Dynamic quantization support for optimal quality/performance balance

### Quick Performance Setup

1. Test your configuration:
   ```bash
   ./test-performance.sh
   ```

2. Run performance benchmarks:
   ```bash
   ../../scripts/testing/benchmark-mistral.sh
   ```

3. View detailed tuning guide:
   ```bash
   cat ../../docs/performance-tuning.md
   ```

### Key Performance Settings

For Mac Studio Ultra (recommended settings in `.env`):

```bash
# Metal Acceleration
MISTRAL_DEVICE=metal
MISTRAL_USE_FLASH_ATTENTION=true
MISTRAL_METAL_HEAP_SIZE=68719476736  # 64GB

# Memory Optimization
MISTRAL_MEMORY_FRACTION=0.9
MISTRAL_ENABLE_MEMORY_POOLING=true
MISTRAL_MAX_SEQ_LEN=32768

# Performance Tuning
MISTRAL_ENABLE_CONTINUOUS_BATCHING=true
MISTRAL_DEFAULT_QUANTIZATION=q5_k_m
```

## Troubleshooting

### Common Issues

1. **Port Conflicts**
   - If port 8080 is already in use, change `MISTRAL_API_PORT` in `.env`
   - Check what's using the port: `lsof -i :8080`

2. **Missing Models**
   - Ensure you've downloaded at least one model using `./download-model.sh`
   - Models should be in the path specified by `MISTRAL_MODELS_PATH`

3. **Memory Issues**
   - Reduce `MISTRAL_MEMORY_LIMIT` and `MISTRAL_MEMORY_RESERVATION` in `.env`
   - Use smaller quantized models (Q4_K_M instead of Q8_0)

4. **GPU/Metal Not Working**
   - macOS: Ensure Docker Desktop has sufficient resources allocated
   - Linux: Check NVIDIA drivers with `nvidia-smi`
   - The service will fall back to CPU if GPU is unavailable

### Debugging Commands

Check logs:
```bash
docker logs -f frontier-mistral
```

Check resource usage:
```bash
docker stats frontier-mistral
```

Test the API:
```bash
curl http://localhost:8080/v1/models
```

Check health status:
```bash
curl http://localhost:8080/health
```