# Ollama Stack Documentation

## Overview

The Ollama stack provides a mature, production-ready LLM inference solution using [Ollama](https://ollama.ai) as the inference engine. This stack is optimized for Mac Studio systems with Apple Silicon but also supports Linux and Windows with various GPU configurations.

### When to Use Ollama Stack

**Ideal for:**
- macOS systems with Apple Silicon (M1/M2/M3)
- Production deployments requiring stability
- Users wanting automatic model management
- Broad model compatibility requirements
- CPU-only deployments as fallback
- Quick setup with minimal configuration

**Advantages:**
- Extensive model library via Ollama Hub
- Automatic model downloads and updates
- Native Metal support for Apple Silicon
- CUDA support for NVIDIA GPUs
- ROCm support for AMD GPUs
- Excellent CPU fallback performance
- Active community and ecosystem

## Components

- **Ollama Server**: The main LLM inference engine
- **Monitoring Stack**: Prometheus, Grafana, and Node Exporter for comprehensive metrics
- **Nginx**: Reverse proxy for secure API access with SSL support
- **Aider** (optional): AI-assisted development environment

## Prerequisites

### Hardware Requirements
- **Recommended**: Mac Studio with M2/M3 Ultra, 64GB+ RAM
- **Minimum**: Any system with 16GB RAM
- **Storage**: 50GB+ free space (more for large models)

### Software Requirements
- Docker Desktop (macOS/Windows) or Docker Engine (Linux)
- Git
- 8GB+ RAM allocated to Docker

## Quick Start

### Step 1: Select Ollama Stack
```bash
./stack-select.sh select ollama
```

### Step 2: Configure Environment
```bash
cp .env.example .env
# Edit .env with your settings
vim .env
```

### Step 3: Start Services
```bash
./start.sh
```

### Step 4: Pull Your First Model
```bash
# Pull recommended model
./pull-model.sh qwen2.5-coder:32b-instruct-q8_0

# Or pull any model from Ollama Hub
./pull-model.sh <model-name>
```

## Configuration

### Environment Variables

Key environment variables in `.env`:

```bash
# Model Storage
OLLAMA_MODELS_PATH=./data/ollama-models  # Where models are stored
OLLAMA_MODEL_PATH=/models                 # Container mount path

# API Configuration
OLLAMA_HOST=0.0.0.0:11434                # API bind address
OLLAMA_ORIGINS=*                         # CORS origins

# Performance Tuning
OLLAMA_KEEP_ALIVE=10m                    # Keep models in memory
OLLAMA_NUM_PARALLEL=4                    # Parallel request handling
OLLAMA_MAX_LOADED_MODELS=2               # Models kept in memory
OLLAMA_NUM_GPU=999                       # GPUs to use (999 = all)

# Resource Limits
OLLAMA_MEMORY_LIMIT=64G                  # Maximum memory
OLLAMA_MEMORY_RESERVATION=32G            # Reserved memory

# GPU Configuration (Optional)
OLLAMA_CUDA_VISIBLE_DEVICES=0,1          # Specific GPUs to use
OLLAMA_ROCM_VISIBLE_DEVICES=0            # AMD GPU selection
```

### Advanced Configuration

For Apple Silicon Macs:
```bash
# Optimize for Metal Performance Shaders
OLLAMA_METAL=1                           # Enable Metal (default)
OLLAMA_METAL_CONTEXT_SIZE=8192          # Context window size
```

For NVIDIA GPUs:
```bash
# CUDA optimization
OLLAMA_CUDA_COMPUTE_CAP=8.6             # Set compute capability
OLLAMA_CUDA_MEMORY_FRACTION=0.9         # GPU memory usage
```

## Model Management

### Available Models

Ollama provides access to a vast library of models. Popular choices include:

| Model | Size | Use Case | Pull Command |
|-------|------|----------|--------------|
| qwen2.5-coder:32b | 19GB | Advanced coding | `./pull-model.sh qwen2.5-coder:32b-instruct-q8_0` |
| deepseek-coder:33b | 19GB | Code generation | `./pull-model.sh deepseek-coder:33b-instruct-q8_0` |
| llama3.1:70b | 40GB | General purpose | `./pull-model.sh llama3.1:70b-instruct-q8_0` |
| mixtral:8x7b | 26GB | Fast inference | `./pull-model.sh mixtral:8x7b-instruct-q8_0` |
| phi3:medium | 7.9GB | Lightweight | `./pull-model.sh phi3:medium` |

### Model Operations

```bash
# List installed models
curl http://localhost:11434/api/tags

# Pull a model
curl -X POST http://localhost:11434/api/pull \
  -d '{"name": "llama3.1:70b"}'

# Delete a model
curl -X DELETE http://localhost:11434/api/delete \
  -d '{"name": "llama3.1:70b"}'

# Copy/alias a model
curl -X POST http://localhost:11434/api/copy \
  -d '{"source": "llama3.1:70b", "destination": "mymodel"}'
```

### Custom Models

Create custom models with Modelfiles:

```dockerfile
# Modelfile
FROM llama3.1:70b

# Set parameters
PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.1

# Set system prompt
SYSTEM "You are a helpful coding assistant specialized in Python."

# Set template
TEMPLATE """{{ .System }}
User: {{ .Prompt }}
Assistant: """
```

Create the model:
```bash
ollama create myassistant -f Modelfile
```

## API Usage

### Generate Completion
```bash
curl http://localhost:11434/api/generate \
  -d '{
    "model": "qwen2.5-coder:32b",
    "prompt": "Write a Python function to calculate fibonacci numbers",
    "stream": false
  }'
```

### Chat Completion
```bash
curl http://localhost:11434/api/chat \
  -d '{
    "model": "qwen2.5-coder:32b",
    "messages": [
      {"role": "user", "content": "Explain quantum computing"}
    ]
  }'
```

### Embeddings
```bash
curl http://localhost:11434/api/embeddings \
  -d '{
    "model": "nomic-embed-text",
    "prompt": "The sky is blue"
  }'
```

## Using with Aider

### Configuration
```bash
# Set Ollama endpoint
export OLLAMA_API_BASE="http://localhost:11434"

# Run Aider with Ollama model
aider --model ollama/qwen2.5-coder:32b-instruct-q8_0
```

### Aider Settings (.aider.conf.yml)
```yaml
model: ollama/qwen2.5-coder:32b-instruct-q8_0
edit-format: diff
auto-commits: false
dirty-commits: false
```

## Monitoring

### Grafana Dashboards

Access at `http://localhost:3000` (default: admin/changeme123!)

Available dashboards:
- **System Overview**: CPU, memory, disk, network metrics
- **Ollama Metrics**: Request rates, response times, model loading
- **GPU Metrics**: Utilization, memory, temperature (if applicable)

### Prometheus Queries

Useful queries for monitoring:

```promql
# Request rate
rate(ollama_request_duration_seconds_count[5m])

# Average response time
rate(ollama_request_duration_seconds_sum[5m]) / rate(ollama_request_duration_seconds_count[5m])

# Memory usage
process_resident_memory_bytes{job="ollama"}

# GPU utilization (NVIDIA)
nvidia_gpu_utilization
```

## Performance Optimization

### Memory Management

1. **Model Loading Strategy:**
   ```bash
   # Keep frequently used models in memory
   OLLAMA_KEEP_ALIVE=30m
   
   # Limit concurrent models
   OLLAMA_MAX_LOADED_MODELS=1  # For limited RAM
   ```

2. **Context Window Optimization:**
   ```bash
   # Reduce context for better performance
   OLLAMA_NUM_CTX=2048  # Default is 4096
   ```

### GPU Optimization

For Apple Silicon:
```bash
# Use all GPU cores
OLLAMA_NUM_GPU=999

# Optimize batch size
OLLAMA_BATCH_SIZE=512
```

For NVIDIA:
```bash
# Use specific GPUs
OLLAMA_CUDA_VISIBLE_DEVICES=0,1

# Enable tensor cores
OLLAMA_CUDA_TENSOR_CORES=true
```

### Quantization Guide

Choose the right quantization for your needs:

| Quantization | Size Reduction | Quality | Speed | Use Case |
|--------------|---------------|---------|-------|----------|
| Q8_0 | ~25% | Excellent | Fast | Production |
| Q6_K | ~40% | Very Good | Faster | Balanced |
| Q5_K_M | ~50% | Good | Faster | Memory-constrained |
| Q4_K_M | ~60% | Acceptable | Fastest | Testing/Development |
| Q4_0 | ~65% | Lower | Fastest | Experimentation |

## Troubleshooting

### Common Issues

1. **Model download fails:**
   ```bash
   # Check disk space
   df -h ./data/ollama-models
   
   # Retry with verbose logging
   OLLAMA_DEBUG=1 ./pull-model.sh model-name
   ```

2. **Out of memory errors:**
   ```bash
   # Reduce memory usage
   OLLAMA_NUM_PARALLEL=1
   OLLAMA_MAX_LOADED_MODELS=1
   
   # Use smaller quantization
   ./pull-model.sh model-name:q4_0
   ```

3. **Slow inference:**
   ```bash
   # Check if GPU is being used
   curl http://localhost:11434/api/ps
   
   # Monitor GPU usage
   docker exec ollama nvidia-smi  # NVIDIA
   docker stats ollama            # General
   ```

4. **Connection refused:**
   ```bash
   # Check if Ollama is running
   docker ps | grep ollama
   
   # Check logs
   docker logs ollama
   
   # Test API
   curl http://localhost:11434/api/version
   ```

### Debug Mode

Enable detailed logging:
```bash
# In .env
OLLAMA_DEBUG=1
OLLAMA_LOG_LEVEL=debug

# Restart services
./stop.sh && ./start.sh

# View logs
docker logs -f ollama
```

## Migration Guide

### From Native Ollama

If migrating from native Ollama installation:

1. **Export existing models:**
   ```bash
   # On native installation
   ollama list  # Note your models
   ls ~/.ollama/models
   ```

2. **Copy model files:**
   ```bash
   # Copy to Docker volume
   cp -r ~/.ollama/models/* ./data/ollama-models/
   ```

3. **Update configurations:**
   ```bash
   # Update .env with your preferences
   vim .env
   ```

### To Mistral.rs Stack

To migrate to Mistral.rs:

1. **Note your models and settings**
2. **Stop Ollama stack:** `./stop.sh`
3. **Select Mistral:** `./stack-select.sh select mistral`
4. **Download equivalent models in GGUF format**
5. **Update API endpoints in your applications**

## Security Best Practices

1. **Network Security:**
   ```nginx
   # Restrict API access in nginx config
   location /api {
       allow 192.168.1.0/24;
       deny all;
   }
   ```

2. **Authentication:**
   ```bash
   # Use nginx basic auth
   htpasswd -c /etc/nginx/.htpasswd username
   ```

3. **SSL/TLS:**
   ```bash
   # Enable HTTPS in nginx
   # Place certs in config/ssl/
   ```

## Backup and Recovery

### Backup Models
```bash
# Backup model directory
tar -czf ollama-models-backup.tar.gz ./data/ollama-models/
```

### Backup Configuration
```bash
# Backup environment and configs
tar -czf ollama-config-backup.tar.gz .env config/ollama/
```

### Restore
```bash
# Restore models
tar -xzf ollama-models-backup.tar.gz

# Restore configuration
tar -xzf ollama-config-backup.tar.gz
```

## Advanced Features

### Multi-Model Serving
```bash
# Run multiple models simultaneously
OLLAMA_MAX_LOADED_MODELS=3
OLLAMA_NUM_PARALLEL=8
```

### Custom Endpoints
Configure custom endpoints in nginx:
```nginx
location /coding-assistant {
    proxy_pass http://ollama:11434/api/generate;
    proxy_set_header X-Model "qwen2.5-coder:32b";
}
```

### Monitoring Webhooks
Set up alerts in Grafana for:
- High memory usage
- Slow response times
- Model loading failures

## Resources

- [Ollama Documentation](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Ollama Model Library](https://ollama.ai/library)
- [Ollama Discord](https://discord.gg/ollama)
- [Performance Tuning Guide](../performance-tuning.md)
- [Resource Allocation Guide](../resource-allocation.md)