# Mistral Stack Documentation

## Overview

The Mistral stack provides a high-performance LLM inference solution using [mistral.rs](https://github.com/EricLBuehler/mistral.rs) as the inference engine. This stack is designed for systems with NVIDIA GPUs and focuses on performance and efficiency through Rust-based implementation.

### When to Use Mistral.rs Stack

**Ideal for:**
- Linux systems with NVIDIA GPUs (CUDA 11.7+)
- Applications requiring OpenAI API compatibility
- High-throughput inference workloads
- Users comfortable with manual model management
- Experimental and cutting-edge deployments

**Not recommended for:**
- macOS systems (no Metal support)
- CPU-only deployments
- Users requiring extensive model library access
- Production environments requiring maximum stability

## Components

- **Mistral.rs Server**: High-performance Rust-based LLM inference engine
- **CUDA Support**: Optimized for NVIDIA GPUs with configurable CUDA version
- **Monitoring Integration**: Full Prometheus, Grafana, and Node Exporter support
- **Nginx Reverse Proxy**: Secure API access with SSL termination

## Prerequisites

- Docker and Docker Compose
- NVIDIA GPU with CUDA support
- NVIDIA Docker runtime (nvidia-docker2)
- At least 64GB RAM (configurable)
- Sufficient disk space for models

## Quick Start

1. **Select the Mistral stack:**
   ```bash
   ./stack-select.sh select mistral
   ```

2. **Configure environment variables:**
   ```bash
   cp stacks/mistral/.env.example .env
   # Edit .env with your specific configuration
   ```

3. **Start the stack:**
   ```bash
   ./start.sh
   ```
   The first time you run this, it will automatically build the Mistral Docker image (build time: 10-30 minutes depending on system).

## Configuration

### Environment Variables

Key environment variables for Mistral stack:

```bash
# Model Configuration
MISTRAL_MODELS_PATH=./data/mistral-models  # Where models are stored
MISTRAL_MODEL_PATH=/models                  # Internal container path
DEFAULT_MODEL=mistral-7b-instruct          # Default model to use

# Resource Configuration
MISTRAL_MEMORY_LIMIT=64G                   # Maximum memory allocation
MISTRAL_MEMORY_RESERVATION=32G             # Reserved memory

# Build Configuration
CUDA_VERSION=12.2.0                        # CUDA version for the image
MISTRAL_RS_VERSION=v0.6.0                  # mistral.rs version to build

# Runtime Configuration
RUST_LOG=info                              # Logging level
MISTRAL_PORT=11434                         # API port (Ollama-compatible)
MISTRAL_HOST=0.0.0.0                       # Bind address
```

### Configuration Files

The stack uses configuration files in `config/mistral/`:

- `config.yml`: Main configuration for mistral.rs server

Example configuration:
```yaml
models:
  path: "/models"
  quantization: "Q4_K_M"
  context_length: 8192

server:
  host: "0.0.0.0"
  port: 11434
  num_threads: 8

inference:
  temperature: 0.7
  top_p: 0.9
  max_tokens: 2048
  batch_size: 8
```

## Model Management

### Supported Model Formats

Mistral.rs supports the following model formats:
- GGUF (recommended)
- SafeTensors
- Quantized models (Q4_K_M, Q5_K_M, Q8_0, etc.)

### Installing Models

1. **Download models manually:**
   ```bash
   # Create models directory if it doesn't exist
   mkdir -p ./data/mistral-models

   # Download from Hugging Face (example):
   # For GGUF models:
   wget https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.2-GGUF/resolve/main/mistral-7b-instruct-v0.2.Q4_K_M.gguf \
     -O ./data/mistral-models/mistral-7b-instruct-q4_k_m.gguf

   # For Qwen models:
   wget https://huggingface.co/Qwen/Qwen2.5-Coder-32B-Instruct-GGUF/resolve/main/qwen2.5-coder-32b-instruct-q5_k_m.gguf \
     -O ./data/mistral-models/qwen2.5-coder-32b-q5_k_m.gguf
   ```

2. **Using the pull script (helper for common models):**
   ```bash
   # Script location: stacks/mistral/scripts/pull-model.sh
   ./stacks/mistral/scripts/pull-model.sh <model-name> <quantization>

   # Example:
   ./stacks/mistral/scripts/pull-model.sh qwen2.5-coder:32b q5_k_m
   ```

2. **Model directory structure:**
   ```
   ./data/mistral-models/
   ├── mistral-7b-instruct-q4_k_m.gguf
   ├── mixtral-8x7b-instruct-q5_k_m.gguf
   └── codestral-22b-q8_0.gguf
   ```

3. **Configure model in your API requests:**
   ```bash
   curl http://localhost:11434/api/generate \
     -d '{
       "model": "mistral-7b-instruct-q4_k_m.gguf",
       "prompt": "Hello, world!"
     }'
   ```

## API Compatibility

The Mistral stack provides OpenAI-compatible API endpoints:

- `/v1/chat/completions` - Chat completions (OpenAI-compatible)
- `/v1/completions` - Text completions (OpenAI-compatible)
- `/v1/models` - List available models (used for health checks)

### Example API Usage

```bash
# List models (health check)
curl http://localhost:11434/v1/models

# Chat completion (OpenAI-compatible)
curl -X POST http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistral-7b-instruct-q4_k_m.gguf",
    "messages": [
      {"role": "user", "content": "What is the capital of France?"}
    ],
    "temperature": 0.7
  }'

# Text completion
curl -X POST http://localhost:11434/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistral-7b-instruct-q4_k_m.gguf",
    "prompt": "Explain quantum computing in simple terms:",
    "max_tokens": 200,
    "temperature": 0.7
  }'
```

## Building from Source

To rebuild the Mistral Docker image:

```bash
cd stacks/mistral
./build.sh
```

The build script will:
1. Verify Docker and NVIDIA runtime
2. Check GitHub connectivity
3. Clone the specified version of mistral.rs
4. Build the Rust binary with CUDA support
5. Create the Docker image

## Troubleshooting

### Common Issues

1. **Build fails with CUDA error:**
   - Ensure NVIDIA Docker runtime is installed
   - Check CUDA version compatibility
   - Verify GPU drivers are up to date

2. **Model not found:**
   - Check model path in configuration
   - Ensure model file exists in the models directory
   - Verify file permissions

3. **Out of memory errors:**
   - Adjust `MISTRAL_MEMORY_LIMIT` and `MISTRAL_MEMORY_RESERVATION`
   - Use smaller quantized models
   - Reduce batch size in configuration

4. **API compatibility issues:**
   - Note that mistral.rs may not support all Ollama endpoints
   - Check mistral.rs documentation for supported features
   - Monitor logs for specific error messages
   
   Common error examples:
   - `CUDA out of memory`: Reduce model size or batch size
   - `Model file not found`: Check file path and permissions
   - `Unsupported model format`: Ensure GGUF or SafeTensors format

### Debugging

Enable debug logging:
```bash
# In .env file
RUST_LOG=debug
```

View logs:
```bash
./docker-compose-wrapper.sh logs -f mistral
```

Check container status:
```bash
./docker-compose-wrapper.sh ps
```

## Performance Tuning

### GPU Optimization

1. **CUDA Version:** Match CUDA version to your GPU drivers
   ```bash
   # Check your CUDA version
   nvidia-smi

   # Update CUDA_VERSION in .env to match
   CUDA_VERSION=12.2.0  # or your version
   ```

2. **Compute Capability:** Ensure your GPU meets minimum requirements
   - RTX 3090/4090: Compute 8.6+
   - A100: Compute 8.0
   - V100: Compute 7.0

3. **Memory Pool:** Configure GPU memory pool size in config.yml
   ```yaml
   gpu:
     memory_fraction: 0.9  # Use 90% of GPU memory
     allow_growth: false   # Pre-allocate memory
   ```

### CPU Optimization

1. **Thread Count:** Adjust `num_threads` based on CPU cores
   ```yaml
   server:
     num_threads: 16  # Set to physical core count
   ```

2. **Batch Size:** Balance between throughput and latency
   ```yaml
   inference:
     batch_size: 8   # Increase for throughput
     # batch_size: 1  # Decrease for latency
   ```

3. **Context Length:** Reduce for better performance if not needed
   ```yaml
   models:
     context_length: 4096  # Reduce from 8192 if not needed
   ```

### Quantization Recommendations

| Model Size | Quantization | VRAM Usage | Quality | Speed |
|------------|-------------|------------|---------|-------|
| 7B | Q4_K_M | ~4GB | Good | Fast |
| 7B | Q5_K_M | ~5GB | Better | Fast |
| 7B | Q8_0 | ~7GB | Best | Moderate |
| 32B | Q4_K_M | ~18GB | Good | Moderate |
| 32B | Q5_K_M | ~22GB | Better | Moderate |
| 32B | Q8_0 | ~33GB | Best | Slower |

*Note: Memory usage and performance estimates are approximate and may vary based on specific hardware and configuration.

## Security Considerations

1. **Network Security:**
   - API is exposed on port 11434 by default
   - Use Nginx reverse proxy for SSL termination
   - Configure firewall rules appropriately

2. **Model Security:**
   - Verify model sources before downloading
   - Keep models in secure locations with appropriate permissions
   - Monitor for unusual model behavior
   - Use checksums to verify model integrity
   - Avoid running untrusted models

3. **Access Control:**
   - Implement authentication if exposing to network
   - Use environment-specific configurations
   - Regularly audit access logs
   - Consider rate limiting for public deployments

4. **Container Security:**
   - Keep Docker images updated
   - Run containers with minimal privileges
   - Use security scanning on images
   - Isolate the stack from other services

## Known Limitations

1. **API Compatibility:**
   - Not all Ollama endpoints are supported
   - OpenAI API subset is implemented
   - No support for Ollama's model management APIs

2. **Model Format:**
   - Limited to GGUF and SafeTensors formats
   - No automatic conversion from other formats
   - Manual quantization may be required

3. **Hardware Requirements:**
   - Currently requires NVIDIA GPU with CUDA 11.7+
   - No support for AMD GPUs (ROCm)
   - No support for Apple Silicon (Metal)
   - CPU-only inference is extremely limited; GPU is strongly recommended

4. **Platform Support:**
   - Primarily tested on Linux with NVIDIA GPUs
   - Docker required (no native installation)
   - Windows support is experimental

5. **Features Not Yet Implemented:**
   - Automatic model downloads
   - Model library browsing
   - Built-in model conversion
   - Multi-GPU inference
   - Function calling/tools support

## Migration from Ollama

If you're migrating from Ollama to Mistral.rs:

1. **API Endpoint Changes:**
   ```bash
   # Ollama
   curl http://localhost:11434/api/generate

   # Mistral.rs (OpenAI-compatible)
   curl http://localhost:11434/v1/completions
   ```

2. **Model Name Format:**
   - Ollama: `qwen2.5-coder:32b-instruct-q8_0`
   - Mistral.rs: `qwen2.5-coder-32b-q8_0.gguf`

3. **Environment Variables:**
   ```bash
   # Ollama
   OLLAMA_HOST=0.0.0.0
   OLLAMA_MODELS=/models

   # Mistral.rs
   MISTRAL_HOST=0.0.0.0
   MISTRAL_MODELS_PATH=/models
   ```

4. **Client Configuration:**
   ```python
   # For OpenAI Python client
   from openai import OpenAI

   client = OpenAI(
       base_url="http://localhost:11434/v1",
       api_key="not-needed"  # Mistral.rs doesn't require API keys
   )
   ```

## Contributing

See the main project CONTRIBUTING.md for guidelines. Key areas for contribution:
- API compatibility improvements
- Model format support
- Performance optimizations
- Documentation enhancements

## Resources

- [mistral.rs GitHub](https://github.com/EricLBuehler/mistral.rs)
- [mistral.rs Documentation](https://github.com/EricLBuehler/mistral.rs/wiki)
- [Model Quantization Guide](https://github.com/EricLBuehler/mistral.rs/wiki/Quantization)
- [NVIDIA Docker Documentation](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/)