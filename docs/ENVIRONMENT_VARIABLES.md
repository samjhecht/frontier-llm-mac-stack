# Environment Variables Reference

This document provides a comprehensive reference for all environment variables used in the Frontier LLM Stack.

## Common Variables

Variables used across all stacks:

### Monitoring & Metrics

| Variable | Default | Description |
|----------|---------|-------------|
| `GRAFANA_ADMIN_USER` | `admin` | Grafana admin username |
| `GRAFANA_ADMIN_PASSWORD` | `changeme123!` | Grafana admin password (change in production) |
| `PROMETHEUS_PORT` | `9090` | Prometheus metrics server port |
| `GRAFANA_PORT` | `3000` | Grafana dashboard port |
| `NODE_EXPORTER_PORT` | `9100` | Node exporter metrics port |

### Networking

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_HTTP_PORT` | `80` | HTTP port for Nginx proxy |
| `NGINX_HTTPS_PORT` | `443` | HTTPS port for Nginx proxy |
| `SSL_CERT_PATH` | `./config/ssl/cert.pem` | Path to SSL certificate |
| `SSL_KEY_PATH` | `./config/ssl/key.pem` | Path to SSL private key |

## Ollama Stack Variables

### Core Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_HOST` | `0.0.0.0:11434` | API bind address and port |
| `OLLAMA_MODELS_PATH` | `./data/ollama-models` | Host path for model storage |
| `OLLAMA_MODEL_PATH` | `/models` | Container mount path for models |
| `OLLAMA_ORIGINS` | `*` | CORS allowed origins |

### Performance Tuning

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_KEEP_ALIVE` | `10m` | Time to keep models loaded in memory |
| `OLLAMA_NUM_PARALLEL` | `4` | Number of parallel requests |
| `OLLAMA_MAX_LOADED_MODELS` | `2` | Maximum models kept in memory |
| `OLLAMA_NUM_CTX` | `4096` | Context window size |
| `OLLAMA_BATCH_SIZE` | `512` | Batch size for processing |
| `OLLAMA_NUM_THREAD` | (auto) | Number of CPU threads |

### GPU Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_NUM_GPU` | `999` | Number of GPU layers (999 = all) |
| `OLLAMA_CUDA_VISIBLE_DEVICES` | (all) | Specific NVIDIA GPUs to use |
| `OLLAMA_ROCM_VISIBLE_DEVICES` | (all) | Specific AMD GPUs to use |
| `OLLAMA_METAL` | `1` | Enable Metal on macOS |
| `OLLAMA_METAL_CONTEXT_SIZE` | `8192` | Metal context size |
| `OLLAMA_CUDA_COMPUTE_CAP` | (auto) | CUDA compute capability |
| `OLLAMA_CUDA_MEMORY_FRACTION` | `0.9` | GPU memory usage fraction |
| `OLLAMA_CUDA_TENSOR_CORES` | `true` | Enable tensor cores |

### Resource Limits

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_MEMORY_LIMIT` | `64G` | Maximum memory allocation |
| `OLLAMA_MEMORY_RESERVATION` | `32G` | Reserved memory |
| `OLLAMA_CPU_LIMIT` | (unlimited) | CPU core limit |
| `OLLAMA_CPU_RESERVATION` | `4` | Reserved CPU cores |

### Debugging

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_DEBUG` | `0` | Enable debug logging (0/1) |
| `OLLAMA_LOG_LEVEL` | `info` | Log level (debug/info/warn/error) |

## Mistral.rs Stack Variables

### Core Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `MISTRAL_HOST` | `0.0.0.0` | API bind address |
| `MISTRAL_PORT` | `11434` | API port |
| `MISTRAL_MODELS_PATH` | `./data/mistral-models` | Host path for models |
| `MISTRAL_MODEL_PATH` | `/models` | Container mount path |
| `DEFAULT_MODEL` | `mistral-7b-instruct` | Default model name |

### Build Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `CUDA_VERSION` | `12.2.0` | CUDA version for build |
| `MISTRAL_RS_VERSION` | `v0.6.0` | mistral.rs version |
| `RUST_VERSION` | `1.75` | Rust version for build |

### Performance Tuning

| Variable | Default | Description |
|----------|---------|-------------|
| `MISTRAL_NUM_THREADS` | `8` | Number of CPU threads |
| `MISTRAL_BATCH_SIZE` | `8` | Inference batch size |
| `MISTRAL_CONTEXT_LENGTH` | `8192` | Maximum context length |
| `MISTRAL_MAX_TOKENS` | `2048` | Maximum output tokens |

### Resource Limits

| Variable | Default | Description |
|----------|---------|-------------|
| `MISTRAL_MEMORY_LIMIT` | `64G` | Maximum memory allocation |
| `MISTRAL_MEMORY_RESERVATION` | `32G` | Reserved memory |
| `MISTRAL_GPU_MEMORY_FRACTION` | `0.9` | GPU memory usage fraction |

### Debugging

| Variable | Default | Description |
|----------|---------|-------------|
| `RUST_LOG` | `info` | Rust log level |
| `RUST_BACKTRACE` | `0` | Enable backtraces (0/1/full) |

## Docker Compose Variables

### Service Control

| Variable | Default | Description |
|----------|---------|-------------|
| `COMPOSE_PROJECT_NAME` | `frontier-llm` | Docker Compose project name |
| `COMPOSE_FILE` | (auto) | Override compose file selection |
| `COMPOSE_PROFILES` | (auto) | Active compose profiles |

### Resource Management

| Variable | Default | Description |
|----------|---------|-------------|
| `DOCKER_DEFAULT_PLATFORM` | (auto) | Default platform for builds |
| `DOCKER_BUILDKIT` | `1` | Enable BuildKit |
| `COMPOSE_HTTP_TIMEOUT` | `120` | HTTP timeout for operations |

## Aider Integration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_API_BASE` | `http://localhost:11434` | Ollama API endpoint for Aider |
| `OPENAI_API_BASE` | `http://localhost:11434/v1` | OpenAI-compatible endpoint |
| `AIDER_MODEL` | (varies) | Default model for Aider |
| `AIDER_EDIT_FORMAT` | `diff` | Edit format (diff/whole) |
| `AIDER_AUTO_COMMITS` | `false` | Enable auto-commits |

## Environment File Examples

### Minimal Ollama Configuration (.env)
```bash
# Basic Ollama setup
OLLAMA_HOST=0.0.0.0:11434
OLLAMA_MODELS_PATH=./data/ollama-models
OLLAMA_MEMORY_LIMIT=32G
GRAFANA_ADMIN_PASSWORD=mysecurepassword
```

### High-Performance Mistral Configuration (.env)
```bash
# Mistral.rs with GPU optimization
MISTRAL_HOST=0.0.0.0
MISTRAL_PORT=11434
MISTRAL_MODELS_PATH=./data/mistral-models
CUDA_VERSION=12.2.0
MISTRAL_MEMORY_LIMIT=128G
MISTRAL_GPU_MEMORY_FRACTION=0.95
MISTRAL_BATCH_SIZE=16
RUST_LOG=info
GRAFANA_ADMIN_PASSWORD=mysecurepassword
```

### Development Configuration (.env)
```bash
# Development setup with debugging
OLLAMA_DEBUG=1
OLLAMA_LOG_LEVEL=debug
OLLAMA_KEEP_ALIVE=5m
OLLAMA_NUM_PARALLEL=1
OLLAMA_MAX_LOADED_MODELS=1
GRAFANA_ADMIN_PASSWORD=dev123
COMPOSE_HTTP_TIMEOUT=300
```

## Best Practices

1. **Security**
   - Always change default passwords in production
   - Use strong, unique passwords for all services
   - Store sensitive values in `.env` file, never commit to git
   - Use environment-specific `.env` files (.env.production, .env.development)

2. **Performance**
   - Start with conservative memory limits and increase as needed
   - Monitor actual usage before setting final values
   - Use quantized models for memory-constrained environments
   - Adjust parallel requests based on available resources

3. **Debugging**
   - Enable debug logging only when troubleshooting
   - Disable debug mode in production for performance
   - Use structured logging for easier parsing
   - Monitor logs regularly for warnings and errors

4. **Model Management**
   - Keep frequently used models loaded with appropriate KEEP_ALIVE
   - Limit loaded models based on available memory
   - Use model aliases for easier switching
   - Regular cleanup of unused models

## Stack-Specific Defaults

The `.env.example` file in each stack directory contains recommended defaults:

- `stacks/ollama/.env.example` - Ollama-optimized settings
- `stacks/mistral/.env.example` - Mistral.rs-optimized settings
- `stacks/common/.env.example` - Shared service settings

Copy the appropriate example file when switching stacks:
```bash
./stack-select.sh select ollama
cp stacks/ollama/.env.example .env
# Edit .env with your specific values
```