# Step 8: Initial Model Pull (Qwen2.5-Coder)

## Overview
Pull and configure the initial Qwen2.5-Coder 32B model for testing and development. This model provides a good balance of performance and resource usage before upgrading to larger models.

## Tasks
1. Pull Qwen2.5-Coder 32B model with Q8 quantization
2. Monitor download progress and system resources
3. Verify model loads correctly
4. Test basic inference
5. Configure model parameters

## Implementation Details

### 1. Model Pull Script
Create `scripts/models/pull-initial-model.sh`:
```bash
#!/bin/bash
set -euo pipefail

MODEL="qwen2.5-coder:32b-instruct-q8_0"
echo "Pulling model: $MODEL"

# Check available disk space
available_space=$(df -g ~/ollama-models | awk 'NR==2 {print $4}')
echo "Available disk space: ${available_space}GB"

# Model requires ~35GB for Q8 quantization
if [[ $available_space -lt 50 ]]; then
    echo "Warning: Low disk space. Model requires ~35GB"
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Pull model with progress monitoring
docker compose exec -T ollama ollama pull $MODEL

# Verify model was pulled
docker compose exec -T ollama ollama list | grep "$MODEL"
```

### 2. Model Testing
```bash
# Test basic generation
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-coder:32b-instruct-q8_0",
    "prompt": "Write a Python function to calculate fibonacci numbers",
    "stream": false,
    "options": {
      "temperature": 0.7,
      "top_p": 0.9,
      "num_predict": 200
    }
  }'
```

### 3. Performance Baseline
Create `scripts/testing/model-benchmark.sh`:
```bash
#!/bin/bash
# Benchmark model performance
# - Token generation speed
# - Memory usage
# - Response latency
# - Concurrent request handling
```

### 4. Model Configuration
Create Ollama modelfile for custom parameters:
```
FROM qwen2.5-coder:32b-instruct-q8_0

PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.1
PARAMETER num_ctx 4096

SYSTEM "You are an expert software engineer and coding assistant."
```

## Dependencies
- Step 5: Ollama service running
- Sufficient disk space (50GB+ recommended)
- Stable network connection

## Success Criteria
- Model successfully downloaded
- Model appears in `ollama list`
- Test generation produces valid code
- Response time < 5 seconds for simple prompts
- Memory usage stays within limits

## Testing
```bash
# List models
docker compose exec ollama ollama list

# Test generation
./scripts/testing/test-model-generation.sh

# Monitor resources during generation
docker stats ollama
```

## Notes
- Initial download may take 30-60 minutes depending on connection
- Q8 quantization provides good quality/size balance
- Monitor Grafana during download for resource usage
- Consider pulling during off-peak hours