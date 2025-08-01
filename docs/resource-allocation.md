# Resource Allocation Guide

This guide helps you configure optimal resource allocation for the Frontier LLM Stack based on your hardware and use case.

## Quick Reference

### Memory Requirements by Model Size

| Model Size | Minimum RAM | Recommended RAM | Optimal RAM |
|------------|-------------|-----------------|-------------|
| 7B (Q4)    | 8GB         | 16GB           | 32GB        |
| 13B (Q4)   | 16GB        | 32GB           | 64GB        |
| 22B (Q4)   | 24GB        | 48GB           | 64GB        |
| 32B (Q8)   | 64GB        | 96GB           | 128GB       |
| 70B (Q4)   | 48GB        | 96GB           | 192GB       |
| 235B (Q4)  | 128GB       | 192GB          | 256GB+      |

### Stack Resource Defaults

| Component | Default Memory Limit | Default Reservation | Configurable Via |
|-----------|---------------------|---------------------|------------------|
| Ollama    | 64GB                | 32GB                | `OLLAMA_MEMORY_LIMIT/RESERVATION` |
| Mistral   | 64GB                | 32GB                | `MISTRAL_MEMORY_LIMIT/RESERVATION` |
| Prometheus| 2GB                 | 1GB                 | Docker Compose |
| Grafana   | 1GB                 | 512MB               | Docker Compose |
| Nginx     | 512MB               | 256MB               | Docker Compose |

## Configuration

### Environment Variables

Configure memory limits in your `.env` file:

```bash
# Ollama Stack
OLLAMA_MEMORY_LIMIT=64G          # Maximum memory Ollama can use
OLLAMA_MEMORY_RESERVATION=32G    # Guaranteed memory for Ollama
OLLAMA_NUM_PARALLEL=4            # Concurrent request handling
OLLAMA_MAX_LOADED_MODELS=2       # Models kept in memory

# Mistral Stack
MISTRAL_MEMORY_LIMIT=64G         # Maximum memory Mistral can use
MISTRAL_MEMORY_RESERVATION=32G   # Guaranteed memory for Mistral
```

### Docker Desktop Configuration (macOS)

1. Open Docker Desktop
2. Go to Settings → Resources
3. Configure:
   - **Memory**: Set to 80% of your system RAM
   - **CPUs**: Set to number of cores - 2
   - **Swap**: 2-4GB (helps with memory spikes)
   - **Disk image size**: 200GB+ for model storage

### System-Level Configuration

#### macOS Optimization

```bash
# Disable sleep to prevent interruptions
sudo pmset -a sleep 0
sudo pmset -a disksleep 0

# Disable App Nap for Docker
defaults write com.docker.docker NSAppSleepDisabled -bool YES
```

## Model-Specific Recommendations

### Small Models (7B-13B)

**Use Case**: Development, testing, quick responses

```bash
# .env configuration
OLLAMA_MEMORY_LIMIT=32G
OLLAMA_MEMORY_RESERVATION=16G
OLLAMA_NUM_PARALLEL=4
OLLAMA_MAX_LOADED_MODELS=3
```

**Recommended Models**:
- `mistral:7b-instruct-q4_K_M` (4GB)
- `llama2:13b-chat-q4_K_M` (8GB)
- `codellama:13b-code-q4_K_M` (8GB)

### Medium Models (22B-32B)

**Use Case**: Production coding assistance, complex tasks

```bash
# .env configuration
OLLAMA_MEMORY_LIMIT=64G
OLLAMA_MEMORY_RESERVATION=48G
OLLAMA_NUM_PARALLEL=2
OLLAMA_MAX_LOADED_MODELS=1
```

**Recommended Models**:
- `qwen2.5-coder:32b-instruct-q8_0` (35GB)
- `codestral:22b-v0.1-q5_K_M` (16GB)
- `deepseek-coder:33b-instruct-q4_K_M` (20GB)

### Large Models (70B+)

**Use Case**: State-of-the-art performance, research

```bash
# .env configuration
OLLAMA_MEMORY_LIMIT=192G
OLLAMA_MEMORY_RESERVATION=128G
OLLAMA_NUM_PARALLEL=1
OLLAMA_MAX_LOADED_MODELS=1
OLLAMA_KEEP_ALIVE=5m  # Unload models faster
```

**Recommended Models**:
- `llama2:70b-chat-q4_K_M` (40GB)
- `mixtral:8x7b-instruct-q4_K_M` (26GB)
- `qwen3:235b-instruct-q4_K_M` (130GB) - when available

## Performance Tuning

### GPU Acceleration

#### NVIDIA GPUs (Linux/Windows)
```bash
# Ensure CUDA is utilized
CUDA_VISIBLE_DEVICES=0
MISTRAL_MEMORY_LIMIT=24G  # Leave room for GPU memory
```

#### Apple Silicon (Metal)
Ollama automatically uses Metal Performance Shaders. No additional configuration needed.

### CPU Optimization

```bash
# For CPU-only inference
OMP_NUM_THREADS=8        # Set to number of physical cores
OLLAMA_NUM_THREAD=8      # Match OMP_NUM_THREADS
```

### Batch Processing

For handling multiple requests efficiently:

```bash
# High throughput configuration
OLLAMA_NUM_PARALLEL=8         # Increase parallel processing
OLLAMA_MAX_LOADED_MODELS=1    # Keep only one model loaded
OLLAMA_FLASH_ATTENTION=true   # Enable optimized attention
```

### Low Memory Systems

For systems with limited RAM:

```bash
# Memory-constrained configuration
OLLAMA_MEMORY_LIMIT=16G
OLLAMA_MEMORY_RESERVATION=8G
OLLAMA_NUM_PARALLEL=1
OLLAMA_MAX_LOADED_MODELS=1
OLLAMA_KEEP_ALIVE=1m          # Aggressive unloading
```

Use smaller quantizations:
- Q3_K_S instead of Q4_K_M
- Q2_K instead of Q3_K_S (significant quality loss)

## Monitoring Resource Usage

### Real-time Monitoring

```bash
# View Docker container stats
docker stats

# Check specific container
docker stats frontier-ollama

# System-wide memory usage (macOS)
vm_stat

# Detailed memory info
top -o mem
```

### Grafana Dashboards

Access pre-configured dashboards at `http://localhost:3000`:
- **Container Metrics**: CPU, memory, network I/O per container
- **Model Performance**: Request latency, throughput, queue depth
- **System Overview**: Total resource utilization

### Prometheus Queries

Useful queries for resource monitoring:

```promql
# Container memory usage
container_memory_usage_bytes{name="frontier-ollama"}

# Memory usage percentage
100 * (container_memory_usage_bytes{name="frontier-ollama"} / container_spec_memory_limit_bytes{name="frontier-ollama"})

# CPU usage
rate(container_cpu_usage_seconds_total{name="frontier-ollama"}[5m])
```

## Troubleshooting

### Out of Memory Errors

**Symptoms**: Container crashes, "killed" status, slow responses

**Solutions**:
1. Reduce memory limits in `.env`
2. Use smaller model quantizations
3. Decrease `OLLAMA_MAX_LOADED_MODELS`
4. Enable swap in Docker Desktop
5. Use `OLLAMA_KEEP_ALIVE=30s` for aggressive unloading

### Slow Performance

**Symptoms**: High latency, timeouts, poor throughput

**Solutions**:
1. Check if models are being repeatedly loaded/unloaded
2. Increase `OLLAMA_KEEP_ALIVE` to keep models in memory
3. Reduce `OLLAMA_NUM_PARALLEL` if CPU-bound
4. Monitor disk I/O - model loading is I/O intensive
5. Use SSD storage for model files

### Container Restart Loops

**Symptoms**: Container repeatedly starts and stops

**Solutions**:
1. Check logs: `docker-compose logs <service>`
2. Reduce memory reservation
3. Ensure sufficient disk space
4. Verify model files aren't corrupted

## Best Practices

1. **Start Conservative**: Begin with lower memory limits and increase as needed
2. **Monitor Actively**: Use Grafana dashboards during initial setup
3. **Profile Your Workload**: Different models and prompts have different memory patterns
4. **Plan for Peaks**: Leave 20% headroom for memory spikes
5. **Use Appropriate Quantization**: Balance quality vs resource usage
6. **Regular Maintenance**: Clear old models and logs periodically

## Advanced Configuration

### NUMA Optimization (Multi-CPU Systems)

```bash
# Pin container to specific NUMA node
docker run --cpuset-cpus="0-15" --cpuset-mems="0" ...
```

### Cgroup Limits

For fine-grained control:

```yaml
# In docker-compose.yml
services:
  ollama:
    deploy:
      resources:
        limits:
          cpus: '8.0'
          memory: 64G
        reservations:
          cpus: '4.0'
          memory: 32G
          devices:
            - capabilities: [gpu]
```

### Kernel Parameters (Linux)

```bash
# Increase memory limits
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
sysctl -p

# Disable swap for predictable performance
swapoff -a
```

## Stack-Specific Considerations

### Ollama Stack
- Automatic memory management
- Supports model hot-swapping
- Uses mmap for efficient loading
- Benefits from fast SSD storage

### Mistral Stack
- More aggressive memory usage
- Requires pre-loaded models
- Better batch processing performance
- Optimized for CUDA acceleration

## Scaling Guidelines

### Vertical Scaling (Bigger Machine)
- Most effective for large models
- Linear performance improvement with RAM
- Consider Mac Studio M3 Ultra (192GB)

### Horizontal Scaling (Multiple Machines)
- Use load balancer (Nginx included)
- Distribute models across nodes
- Requires external model storage

### Model Optimization
- Use quantization (Q4_K_M recommended)
- Fine-tune smaller models for specific tasks
- Implement prompt caching
- Use structured outputs to reduce tokens

## Appendix: Memory Calculation

### Formula
```
Required Memory = Model Size + Context Memory + Overhead

Where:
- Model Size = Size on disk (quantized)
- Context Memory = max_tokens × batch_size × 4 bytes × num_layers
- Overhead = ~2GB for runtime
```

### Example: 32B Q8 Model
```
Model Size: 35GB
Context (8K tokens, batch 4): 8192 × 4 × 4 × 80 = 10GB
Overhead: 2GB
Total: 47GB minimum, 64GB recommended
```