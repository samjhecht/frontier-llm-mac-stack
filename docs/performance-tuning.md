# Mistral.rs Performance Tuning Guide for Mac Studio

This guide provides detailed information on optimizing Mistral.rs performance on Mac Studio hardware, particularly focusing on Metal acceleration and memory management.

## Table of Contents

1. [Hardware Considerations](#hardware-considerations)
2. [Metal Acceleration](#metal-acceleration)
3. [Memory Optimization](#memory-optimization)
4. [Performance Tuning](#performance-tuning)
5. [Benchmarking](#benchmarking)
6. [Troubleshooting](#troubleshooting)

## Hardware Considerations

### Mac Studio Specifications

Mac Studio models come with different configurations that affect performance:

- **M2 Max**: 12-core CPU, up to 38-core GPU, up to 96GB unified memory
- **M2 Ultra**: 24-core CPU, up to 76-core GPU, up to 192GB unified memory
- **M3 Max**: Enhanced performance cores and improved GPU architecture
- **M3 Ultra**: Further improvements in ML acceleration

### Key Performance Factors

1. **Unified Memory Architecture**: Direct GPU access to system memory
2. **Neural Engine**: Hardware acceleration for ML workloads
3. **High Memory Bandwidth**: Up to 800GB/s on Ultra chips
4. **Metal Performance Shaders**: Optimized GPU compute kernels

## Metal Acceleration

### Configuration

The following environment variables control Metal acceleration:

```bash
# Basic Metal Configuration
MISTRAL_DEVICE=metal                    # Enable Metal backend
MISTRAL_METAL_DEVICE_ID=0              # GPU device ID (0 for primary)
MISTRAL_USE_FLASH_ATTENTION=true       # Enable Flash Attention optimization

# Memory Settings for Mac Studio Ultra
MISTRAL_METAL_HEAP_SIZE=68719476736    # 64GB heap size
MISTRAL_METAL_COMMAND_BUFFER_SIZE=1073741824  # 1GB command buffer

# Advanced Metal Optimizations
MISTRAL_METAL_SHADER_VARIANT=optimized  # Use optimized shaders
MISTRAL_METAL_SIMD_REDUCTION=true      # Enable SIMD operations
MISTRAL_METAL_ASYNC_DISPATCH=true      # Asynchronous GPU dispatch
MISTRAL_METAL_COMMAND_QUEUE_SIZE=64    # Command queue depth
```

### Verification

To verify Metal acceleration is active:

```bash
# Check Docker logs
docker logs frontier-mistral 2>&1 | grep -i metal

# Look for messages like:
# "Metal device: Apple M2 Ultra"
# "Using Metal acceleration"
```

## Memory Optimization

### Memory Configuration

Optimize memory usage based on your Mac Studio configuration:

```bash
# Memory Management
MISTRAL_MEMORY_FRACTION=0.9            # Use 90% of available memory
MISTRAL_ENABLE_MEMORY_POOLING=true     # Enable memory pooling
MISTRAL_MEMORY_POOL_SIZE=8589934592    # 8GB memory pool

# KV Cache Configuration
MISTRAL_KV_CACHE_DTYPE=f16             # Use FP16 for KV cache
MISTRAL_MAX_SEQ_LEN=32768              # Maximum sequence length

# Model Cache
MISTRAL_PREFIX_CACHE_SIZE=2147483648   # 2GB prefix cache
MISTRAL_QUANTIZATION_CACHE_SIZE=1073741824  # 1GB quantization cache
```

### Memory Limits by Model Size

Recommended Docker memory limits based on model size:

| Model Size | Memory Limit | Memory Reservation |
|------------|-------------|--------------------|
| 7B params  | 16G         | 8G                 |
| 13B params | 32G         | 16G                |
| 30B params | 64G         | 32G                |
| 70B params | 128G        | 64G                |

Update in `.env`:
```bash
MISTRAL_MEMORY_LIMIT=64G
MISTRAL_MEMORY_RESERVATION=32G
```

## Performance Tuning

### Batch Processing

```bash
# Batching Configuration
MISTRAL_MAX_BATCH_SIZE=8               # Concurrent requests
MISTRAL_ENABLE_CONTINUOUS_BATCHING=true # Dynamic batching
MISTRAL_MAX_RUNNING_REQUESTS=16        # Maximum parallel requests
MISTRAL_MAX_TOTAL_TOKENS=131072        # Token limit per batch
```

### Thread Configuration

```bash
# CPU Threading
MISTRAL_NUM_THREADS=0                  # 0 = auto-detect optimal threads
MISTRAL_TENSOR_PARALLEL_SIZE=1         # Tensor parallelism
MISTRAL_PIPELINE_PARALLEL_SIZE=1       # Pipeline parallelism
```

### Inference Optimization

```bash
# Chunking for Better Latency
MISTRAL_PREFILL_CHUNK_SIZE=2048        # Prefill chunk size
MISTRAL_DECODE_CHUNK_SIZE=256          # Decode chunk size

# Graph Optimization
MISTRAL_USE_GRAPH_CAPTURE=true         # Enable graph capture
MISTRAL_ENABLE_PREFIX_CACHING=true     # Cache common prefixes
```

### Quantization Settings

Choose quantization based on quality/performance trade-off:

| Quantization | Quality | Speed | Memory Usage |
|--------------|---------|-------|--------------|
| f16          | Best    | Slow  | High         |
| q8_0         | Great   | Good  | Medium       |
| q5_k_m       | Good    | Fast  | Low          |
| q4_k_m       | OK      | Fastest| Lowest       |

```bash
MISTRAL_DEFAULT_QUANTIZATION=q5_k_m
MISTRAL_DYNAMIC_QUANTIZATION=true
```

## Benchmarking

### Running Benchmarks

Use the included benchmark script:

```bash
# Basic benchmark
./scripts/testing/benchmark-mistral.sh

# Custom model and runs
./scripts/testing/benchmark-mistral.sh -m mistral-7b-instruct -n 20 -w 5

# Save results to specific directory
./scripts/testing/benchmark-mistral.sh -o ./my-benchmarks
```

### Interpreting Results

Key metrics to monitor:

1. **Latency**: Time to complete inference
   - Target: < 1s for simple queries
   - Target: < 5s for complex generation

2. **Tokens/Second**: Generation speed
   - Good: > 50 tokens/sec
   - Excellent: > 100 tokens/sec

3. **Time to First Byte (TTFB)**: Streaming responsiveness
   - Target: < 500ms

4. **Memory Usage**: Should stay under configured limits

### Performance Targets

Expected performance on Mac Studio:

| Hardware | Model Size | Quantization | Tokens/sec |
|----------|------------|--------------|------------|
| M2 Max   | 7B         | q5_k_m       | 80-120     |
| M2 Ultra | 7B         | q5_k_m       | 150-200    |
| M2 Ultra | 13B        | q5_k_m       | 80-120     |
| M2 Ultra | 30B        | q4_k_m       | 40-60      |

## Troubleshooting

### Metal Not Detected

```bash
# Check Metal support
system_profiler SPDisplaysDataType | grep Metal

# Verify in container
docker exec frontier-mistral env | grep METAL
```

### Poor Performance

1. **Check quantization**: Ensure appropriate quantization for model size
2. **Verify Metal acceleration**: Check logs for Metal initialization
3. **Monitor memory**: Use `docker stats` to check memory usage
4. **Reduce batch size**: Lower `MISTRAL_MAX_BATCH_SIZE` if OOM
5. **Check thermal throttling**: Monitor Mac Studio temperature

### Memory Issues

```bash
# Reduce memory usage
MISTRAL_MEMORY_FRACTION=0.7           # Use only 70% of memory
MISTRAL_MAX_BATCH_SIZE=4              # Smaller batches
MISTRAL_MAX_SEQ_LEN=16384             # Shorter sequences
MISTRAL_DEFAULT_QUANTIZATION=q4_k_m   # More aggressive quantization
```

### Monitoring Performance

Use the monitoring stack to track performance:

1. **Prometheus metrics**: http://localhost:9090
   - `mistral_generate_duration_seconds`
   - `mistral_http_request_duration_seconds`
   - `mistral_active_requests`

2. **Grafana dashboards**: http://localhost:3000
   - Navigate to "Mistral.rs Metrics" dashboard
   - Monitor latency percentiles and throughput

### Advanced Tuning

For specific workloads, consider:

1. **Long context**: Increase `MISTRAL_MAX_SEQ_LEN` and memory limits
2. **High throughput**: Increase batch size and enable continuous batching
3. **Low latency**: Reduce batch size, enable graph capture
4. **Multi-model**: Use model-specific configuration files

## Best Practices

1. **Start Conservative**: Begin with default settings and tune gradually
2. **Monitor Metrics**: Use Prometheus/Grafana to track performance
3. **Test Thoroughly**: Run benchmarks after each configuration change
4. **Document Changes**: Keep track of what settings work best
5. **Regular Updates**: Keep Mistral.rs and drivers updated

## Example Configurations

### High Throughput Configuration

```bash
# Optimize for many concurrent users
MISTRAL_MAX_BATCH_SIZE=16
MISTRAL_MAX_RUNNING_REQUESTS=32
MISTRAL_ENABLE_CONTINUOUS_BATCHING=true
MISTRAL_DEFAULT_QUANTIZATION=q4_k_m
```

### Low Latency Configuration

```bash
# Optimize for fastest response time
MISTRAL_MAX_BATCH_SIZE=4
MISTRAL_USE_GRAPH_CAPTURE=true
MISTRAL_PREFILL_CHUNK_SIZE=4096
MISTRAL_DEFAULT_QUANTIZATION=q5_k_m
```

### Memory Constrained Configuration

```bash
# For systems with limited memory
MISTRAL_MEMORY_FRACTION=0.6
MISTRAL_MAX_BATCH_SIZE=2
MISTRAL_MAX_SEQ_LEN=8192
MISTRAL_DEFAULT_QUANTIZATION=q3_k_m
```