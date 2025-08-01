# Mistral Stack Documentation

## Overview

The Mistral stack provides a high-performance LLM inference solution using [mistral.rs](https://github.com/EricLBuehler/mistral.rs) as the inference engine. This stack is designed for systems with NVIDIA GPUs and focuses on performance and efficiency through Rust-based implementation.

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
   The first time you run this, it will automatically build the Mistral Docker image.

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
   
   # Download model files to this directory
   # Example: wget https://example.com/model.gguf -O ./data/mistral-models/model.gguf
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
2. **Compute Capability:** Ensure your GPU meets minimum requirements
3. **Memory Pool:** Configure GPU memory pool size in config.yml

### CPU Optimization

1. **Thread Count:** Adjust `num_threads` based on CPU cores
2. **Batch Size:** Balance between throughput and latency
3. **Context Length:** Reduce for better performance if not needed

## Security Considerations

1. **Network Security:**
   - API is exposed on port 11434 by default
   - Use Nginx reverse proxy for SSL termination
   - Configure firewall rules appropriately

2. **Model Security:**
   - Verify model sources before downloading
   - Keep models in secure locations
   - Monitor for unusual model behavior

## Known Limitations

1. **API Compatibility:** Not all Ollama endpoints are supported
2. **Model Format:** Limited to formats supported by mistral.rs
3. **GPU Required:** Currently requires NVIDIA GPU with CUDA
4. **Platform Support:** Primarily tested on Linux with NVIDIA GPUs

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