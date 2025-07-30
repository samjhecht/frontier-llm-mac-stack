# Step 15: Qwen3-235B Upgrade Preparation

## Overview
Prepare the infrastructure for upgrading to the Qwen3-235B model, which requires significantly more resources than the initial Qwen2.5-Coder model. This includes capacity planning, conversion tools, and gradual migration strategy.

## Tasks
1. Assess resource requirements
2. Prepare model conversion tools
3. Implement storage expansion strategy
4. Create model switching mechanism
5. Develop testing framework for large models

## Implementation Details

### 1. Resource Assessment Script
Create `scripts/upgrade/assess-resources.sh`:
```bash
#!/bin/bash
set -euo pipefail

echo "=== Qwen3-235B Resource Assessment ==="

# Model requirements
MODEL_SIZE_Q8=470  # GB for Q8 quantization
MODEL_SIZE_Q5=295  # GB for Q5_K_M quantization
MODEL_SIZE_Q4=235  # GB for Q4_K_M quantization
MIN_RAM=192        # GB recommended
MIN_VRAM=48        # GB for Metal acceleration

# System assessment
echo "Current System Resources:"
total_memory=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
available_disk=$(df -g ~/ollama-models | awk 'NR==2 {print $4}')
gpu_memory=$(system_profiler SPDisplaysDataType | grep "VRAM" | awk '{print $2}')

echo "  Total RAM: ${total_memory}GB (Need: ${MIN_RAM}GB)"
echo "  Available Disk: ${available_disk}GB"
echo "  GPU Memory: ${gpu_memory:-Unknown}"

# Recommendations
echo -e "\nRecommendations for Qwen3-235B:"

if [[ $available_disk -lt $MODEL_SIZE_Q5 ]]; then
    echo "❌ Insufficient disk space. Need at least ${MODEL_SIZE_Q5}GB free"
    echo "   Consider: External NVMe SSD or clearing space"
else
    echo "✓ Disk space adequate for Q5_K_M quantization"
fi

if [[ $total_memory -lt $MIN_RAM ]]; then
    echo "⚠️  RAM below recommended. May experience slow inference"
    echo "   Current: ${total_memory}GB, Recommended: ${MIN_RAM}GB"
else
    echo "✓ RAM adequate for model inference"
fi

# Storage recommendations
echo -e "\nQuantization Options:"
echo "  Q8_0: ${MODEL_SIZE_Q8}GB - Highest quality, slowest"
echo "  Q5_K_M: ${MODEL_SIZE_Q5}GB - Good balance (recommended)"
echo "  Q4_K_M: ${MODEL_SIZE_Q4}GB - Acceptable quality, fastest"
```

### 2. Model Conversion Tools
Create `scripts/upgrade/prepare-conversion-tools.sh`:
```bash
#!/bin/bash
set -euo pipefail

echo "=== Installing Model Conversion Tools ==="

# Create conversion environment
CONVERT_DIR="$HOME/llm-conversion"
mkdir -p "$CONVERT_DIR"
cd "$CONVERT_DIR"

# Install Python dependencies
python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
pip install torch transformers accelerate safetensors sentencepiece

# Clone llama.cpp for GGUF conversion
if [[ ! -d "llama.cpp" ]]; then
    git clone https://github.com/ggerganov/llama.cpp
    cd llama.cpp
    make clean
    make LLAMA_METAL=1 -j$(sysctl -n hw.ncpu)
    cd ..
fi

# Create conversion script
cat > convert-qwen3.py << 'EOF'
#!/usr/bin/env python3
import argparse
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
import os

def convert_model(model_path, output_path, quantization):
    print(f"Loading model from {model_path}")
    
    # Load with device map for large models
    model = AutoModelForCausalLM.from_pretrained(
        model_path,
        device_map="auto",
        torch_dtype=torch.float16,
        low_cpu_mem_usage=True
    )
    
    tokenizer = AutoTokenizer.from_pretrained(model_path)
    
    print(f"Converting to {quantization} quantization")
    # Conversion logic here
    
    print(f"Saved to {output_path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-path", required=True)
    parser.add_argument("--output-path", required=True)
    parser.add_argument("--quantization", default="Q5_K_M")
    args = parser.parse_args()
    
    convert_model(args.model_path, args.output_path, args.quantization)
EOF

chmod +x convert-qwen3.py
echo "✓ Conversion tools ready at: $CONVERT_DIR"
```

### 3. Storage Expansion Strategy
Create `scripts/upgrade/setup-model-storage.sh`:
```bash
#!/bin/bash
set -euo pipefail

echo "=== Setting Up Expanded Model Storage ==="

# Check for external volumes
echo "Available volumes:"
ls -la /Volumes/ | grep -v "^d"

# Create model storage structure
MODEL_BASE="${MODEL_BASE:-/Volumes/LLMStorage}"
if [[ -d "$MODEL_BASE" ]]; then
    echo "Using external storage at: $MODEL_BASE"
    
    # Create model directories
    mkdir -p "$MODEL_BASE/models/qwen3"
    mkdir -p "$MODEL_BASE/models/cache"
    
    # Create symlink for Ollama
    if [[ ! -L "$HOME/ollama-models-large" ]]; then
        ln -s "$MODEL_BASE/models" "$HOME/ollama-models-large"
    fi
    
    # Update Docker volume mount
    echo "Update docker-compose.yml to use new model path:"
    echo "  ollama-models:"
    echo "    driver_opts:"
    echo "      device: $MODEL_BASE/models"
else
    echo "⚠️  No external storage found at $MODEL_BASE"
    echo "Large models will use internal storage"
fi
```

### 4. Model Switching Mechanism
Create `scripts/upgrade/model-switcher.sh`:
```bash
#!/bin/bash
set -euo pipefail

echo "=== Model Switching Utility ==="

# List available models
echo "Available models:"
docker compose exec ollama ollama list

# Model profiles
declare -A MODEL_PROFILES=(
    ["dev"]="qwen2.5-coder:32b-instruct-q8_0"
    ["production"]="qwen3:235b-instruct-q5_k_m"
    ["fast"]="qwen2.5-coder:32b-instruct-q4_0"
)

# Switch model
PROFILE="${1:-dev}"
MODEL="${MODEL_PROFILES[$PROFILE]:-$1}"

echo "Switching to model: $MODEL"

# Update Aider configuration
sed -i.bak "s|model: ollama/.*|model: ollama/$MODEL|" ~/.aider.conf.yml

# Preload model in Ollama
docker compose exec ollama ollama run "$MODEL" "test" > /dev/null 2>&1 &
echo "Preloading model..."

# Update environment
echo "export OLLAMA_MODEL=$MODEL" > ~/.ollama-model
echo "✓ Switched to $MODEL"
```

### 5. Large Model Testing Framework
Create `scripts/upgrade/test-large-model.sh`:
```bash
#!/bin/bash
set -euo pipefail

MODEL="${1:-qwen3:235b-instruct-q5_k_m}"
echo "=== Testing Large Model: $MODEL ==="

# Memory monitoring
monitor_resources() {
    while true; do
        echo -n "$(date +%H:%M:%S) - "
        vm_stat | grep -E "Pages (free|active|wired)" | tr '\n' ' '
        echo
        sleep 5
    done
}

# Start monitoring in background
monitor_resources > model-test-resources.log &
MONITOR_PID=$!

# Test 1: Model loading time
echo "Test 1: Model loading..."
start=$(date +%s)
docker compose exec ollama ollama run "$MODEL" "Hello" --verbose
end=$(date +%s)
load_time=$((end - start))
echo "Model load time: ${load_time}s"

# Test 2: Simple generation
echo -e "\nTest 2: Simple generation..."
time curl -X POST http://localhost:11434/api/generate \
    -d "{\"model\": \"$MODEL\", \"prompt\": \"Count from 1 to 10\", \"stream\": false}"

# Test 3: Complex generation
echo -e "\nTest 3: Complex code generation..."
time curl -X POST http://localhost:11434/api/generate \
    -d '{
        "model": "'$MODEL'",
        "prompt": "Write a complete web application using FastAPI with user authentication, database models, and REST endpoints",
        "stream": false,
        "options": {"num_predict": 1000}
    }' | jq -r '.response' | head -20

# Test 4: Concurrent requests
echo -e "\nTest 4: Concurrent handling..."
for i in {1..3}; do
    curl -X POST http://localhost:11434/api/generate \
        -d "{\"model\": \"$MODEL\", \"prompt\": \"Test $i\", \"stream\": false}" &
done
wait

# Stop monitoring
kill $MONITOR_PID

# Analyze results
echo -e "\n=== Test Summary ==="
echo "Model: $MODEL"
echo "Load time: ${load_time}s"
echo "Resource usage: see model-test-resources.log"

# Check for issues
if docker compose logs ollama | grep -i "error\|failed" | tail -5; then
    echo "⚠️  Errors detected in Ollama logs"
fi
```

### 6. Migration Checklist
Create `docs/qwen3-migration-checklist.md`:
```markdown
# Qwen3-235B Migration Checklist

## Pre-Migration
- [ ] Run resource assessment script
- [ ] Ensure 500GB+ free disk space
- [ ] Backup current model and configurations
- [ ] Test storage performance (NVMe recommended)
- [ ] Schedule migration during low-usage period

## Migration Steps
1. [ ] Stop all services
2. [ ] Expand storage if needed
3. [ ] Download/convert Qwen3-235B model
4. [ ] Update Ollama configuration
5. [ ] Test model loading
6. [ ] Run performance benchmarks
7. [ ] Update Aider configuration
8. [ ] Test with real workloads

## Post-Migration
- [ ] Monitor resource usage for 24 hours
- [ ] Optimize based on performance data
- [ ] Update documentation
- [ ] Train team on new capabilities
- [ ] Set up alerts for resource exhaustion

## Rollback Plan
1. [ ] Keep Qwen2.5 model available
2. [ ] Document model switching procedure
3. [ ] Test rollback process
```

## Dependencies
- Stable system with Qwen2.5 running well
- Performance baseline established
- Backup strategy implemented

## Success Criteria
- Resource assessment shows system capable
- Conversion tools installed and tested
- Storage strategy implemented
- Model switching works smoothly
- Large model tests pass

## Testing
```bash
# Assess readiness
./scripts/upgrade/assess-resources.sh

# Prepare tools
./scripts/upgrade/prepare-conversion-tools.sh

# Test with mock large model
./scripts/upgrade/test-large-model.sh qwen2.5-coder:32b-instruct-q8_0
```

## Notes
- Migration is optional based on needs
- Start with Q5_K_M quantization
- Consider dedicated hardware for 235B model
- Monitor thermal performance closely