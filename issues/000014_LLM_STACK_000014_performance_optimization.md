# Step 14: Performance Optimization

## Overview
Optimize the LLM stack for maximum performance on Mac Studio hardware, including memory management, caching strategies, and system tuning for large model inference.

## Tasks
1. Optimize Docker resource allocation
2. Configure Ollama for Mac Metal acceleration
3. Implement response caching
4. Tune system parameters
5. Create performance monitoring dashboard

## Implementation Details

### 1. Docker Resource Optimization
Create `scripts/optimization/optimize-docker.sh`:
```bash
#!/bin/bash
set -euo pipefail

echo "=== Optimizing Docker Resources ==="

# Get system specs
total_memory=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
total_cpus=$(sysctl -n hw.ncpu)

# Calculate optimal allocation (80% of resources)
docker_memory=$((total_memory * 80 / 100))
docker_cpus=$((total_cpus * 80 / 100))

echo "System: ${total_memory}GB RAM, ${total_cpus} CPUs"
echo "Allocating: ${docker_memory}GB RAM, ${docker_cpus} CPUs to Docker"

# Update Docker Desktop settings via CLI
cat > ~/Library/Group\ Containers/group.com.docker/settings.json << EOF
{
  "memoryMiB": $((docker_memory * 1024)),
  "cpus": $docker_cpus,
  "diskSizeMiB": 204800,
  "filesharingDirectories": ["/Users", "/Volumes", "/tmp", "/private"],
  "experimental": true,
  "kernelForUDP": true,
  "socksProxyPort": 0,
  "swapMiB": 1024,
  "vmType": "vz",
  "rosetta": true
}
EOF

echo "✓ Docker Desktop configuration updated"
echo "Please restart Docker Desktop to apply changes"
```

### 2. Ollama Metal Optimization
Create `config/ollama/metal-optimization.json`:
```json
{
  "gpu_layers": -1,
  "use_mmap": true,
  "use_mlock": false,
  "num_thread": 0,
  "batch_size": 512,
  "context_size": 4096,
  "f16_kv": true,
  "logits_all": false,
  "vocab_only": false,
  "rope_freq_base": 10000,
  "rope_freq_scale": 1.0,
  "numa": false
}
```

Update Ollama environment in `docker-compose.yml`:
```yaml
environment:
  - OLLAMA_FLASH_ATTENTION=true
  - OLLAMA_METAL=1
  - OLLAMA_NUM_GPU=999  # Use all available GPU layers
  - OLLAMA_GPU_OVERHEAD=0  # Minimize overhead
  - OLLAMA_PARALLEL=4  # Parallel request processing
  - OLLAMA_RUNNERS_DIR=/tmp/ollama-runners
```

### 3. Response Caching System
Create `config/nginx/cache.conf`:
```nginx
# Cache configuration
proxy_cache_path /var/cache/nginx/ollama 
    levels=1:2 
    keys_zone=ollama_cache:10m 
    max_size=1g 
    inactive=60m;

# Cache key includes model and prompt hash
proxy_cache_key "$request_method$request_uri$request_body";

# Cache successful responses
map $request_uri $cache_control {
    ~*/api/generate  "public, max-age=3600";
    ~*/api/embeddings  "public, max-age=86400";
    default          "no-cache";
}

location /api/generate {
    # Enable caching for generate endpoint
    proxy_cache ollama_cache;
    proxy_cache_methods POST;
    proxy_cache_valid 200 1h;
    proxy_cache_bypass $http_cache_control;
    
    # Add cache status header
    add_header X-Cache-Status $upstream_cache_status;
    add_header Cache-Control $cache_control;
    
    # Buffer responses for caching
    proxy_buffering on;
    proxy_buffer_size 128k;
    proxy_buffers 4 256k;
    
    proxy_pass http://ollama;
}
```

### 4. System Performance Tuning
Create `scripts/optimization/tune-system.sh`:
```bash
#!/bin/bash
set -euo pipefail

echo "=== System Performance Tuning ==="

# Disable system sleep and hibernation
sudo pmset -a sleep 0
sudo pmset -a hibernatemode 0
sudo pmset -a disksleep 0
sudo pmset -a displaysleep 0

# Optimize network settings
sudo sysctl -w net.inet.tcp.delayed_ack=0
sudo sysctl -w net.inet.tcp.mssdflt=1460
sudo sysctl -w kern.ipc.maxsockbuf=8388608

# Increase file descriptor limits
sudo launchctl limit maxfiles 65536 200000

# Memory pressure settings
sudo sysctl -w vm.compressor_mode=2
sudo sysctl -w vm.swapusage=0

echo "✓ System tuning complete"
```

### 5. Performance Monitoring Dashboard
Create `config/grafana/dashboards/performance-optimization.json`:
```json
{
  "dashboard": {
    "title": "LLM Performance Optimization",
    "panels": [
      {
        "title": "Token Generation Speed",
        "targets": [{
          "expr": "rate(ollama_tokens_generated_total[5m]) / rate(ollama_request_duration_seconds_count[5m])"
        }]
      },
      {
        "title": "Cache Hit Rate",
        "targets": [{
          "expr": "rate(nginx_cache_hits_total[5m]) / (rate(nginx_cache_hits_total[5m]) + rate(nginx_cache_misses_total[5m]))"
        }]
      },
      {
        "title": "GPU Memory Usage",
        "targets": [{
          "expr": "ollama_gpu_memory_used_bytes / ollama_gpu_memory_total_bytes * 100"
        }]
      },
      {
        "title": "Request Queue Depth",
        "targets": [{
          "expr": "ollama_pending_requests"
        }]
      },
      {
        "title": "Model Load Time",
        "targets": [{
          "expr": "histogram_quantile(0.95, rate(ollama_model_load_duration_seconds_bucket[5m]))"
        }]
      }
    ]
  }
}
```

### 6. Performance Testing Script
Create `scripts/optimization/performance-test.sh`:
```bash
#!/bin/bash
set -euo pipefail

echo "=== Performance Testing Suite ==="

# Test configurations
PROMPTS=(
    "Write a quicksort implementation in Python"
    "Explain quantum computing in simple terms"
    "Create a REST API with authentication"
)
ITERATIONS=10

# Warm up cache
echo "Warming up..."
for prompt in "${PROMPTS[@]}"; do
    curl -s -X POST http://localhost/api/generate \
        -d "{\"model\": \"qwen2.5-coder:32b-instruct-q8_0\", \"prompt\": \"$prompt\", \"stream\": false}" \
        > /dev/null
done

# Performance tests
echo -e "\nRunning performance tests..."
for prompt in "${PROMPTS[@]}"; do
    echo -e "\nTesting: ${prompt:0:50}..."
    
    total_time=0
    for ((i=1; i<=ITERATIONS; i++)); do
        start=$(date +%s.%N)
        
        response=$(curl -s -X POST http://localhost/api/generate \
            -H "Cache-Control: no-cache" \
            -d "{\"model\": \"qwen2.5-coder:32b-instruct-q8_0\", \"prompt\": \"$prompt\", \"stream\": false}")
        
        end=$(date +%s.%N)
        duration=$(echo "$end - $start" | bc)
        total_time=$(echo "$total_time + $duration" | bc)
        
        tokens=$(echo "$response" | jq -r '.response' | wc -w)
        tps=$(echo "scale=2; $tokens / $duration" | bc)
        
        echo "  Run $i: ${duration}s, $tokens tokens, $tps tokens/sec"
    done
    
    avg_time=$(echo "scale=3; $total_time / $ITERATIONS" | bc)
    echo "  Average: ${avg_time}s"
done

# Check cache effectiveness
echo -e "\nCache Statistics:"
curl -s http://localhost/nginx_status | grep cache || echo "Cache stats not available"
```

## Dependencies
- All services running
- Monitoring stack operational
- Sufficient system resources

## Success Criteria
- Token generation > 20 tokens/second
- Cache hit rate > 30% for repeated queries
- Model load time < 10 seconds
- Memory usage optimized (no swapping)
- Stable performance under load

## Testing
```bash
# Run optimization scripts
./scripts/optimization/optimize-docker.sh
./scripts/optimization/tune-system.sh

# Test performance
./scripts/optimization/performance-test.sh

# Monitor in Grafana
open http://localhost:3000/d/performance-optimization
```

## Notes
- Metal acceleration crucial for Mac performance
- Cache significantly improves response time
- System tuning may require admin password
- Monitor for thermal throttling on long runs