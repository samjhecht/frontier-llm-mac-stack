# Self-Hosted LLM with Coding Agent: Automated Implementation Plan

> **Note for Automation**: This document is designed to be executed by swissarmyhammer. 
> Replace `username` with the actual Mac Studio username and `mac-studio.local` with the actual hostname throughout execution.

## Executive Summary

This document serves as the implementation guide for swissarmyhammer to automatically set up a self-hosted LLM infrastructure on Mac Studio. The setup begins with Qwen2.5-Coder-32B for rapid deployment and testing, with a clear upgrade path to Qwen3-235B for production use. The solution uses Docker for consistency and includes full observability.

## Architecture Overview

### Components
1. **LLM Infrastructure**: Ollama for model management and serving
2. **Model**: Qwen3-235B (requires ~470GB storage for Q8 quantization)
3. **Coding Agent**: Aider (recommended) - AI pair programming in terminal
4. **API Layer**: Ollama's built-in REST API
5. **Observability**: Prometheus + Grafana for monitoring

### Network Architecture
```
┌─────────────────┐         ┌──────────────────┐
│  MacBook Pro    │   LAN   │   Mac Studio     │
│                 ├─────────┤                  │
│ - Aider Client  │         │ - Ollama Server  │
│ - SSH Client    │         │ - Qwen3-235B     │
│                 │         │ - Monitoring     │
└─────────────────┘         └──────────────────┘
```

## Phase 1: Environment Preparation

### 1.1 Pre-requisites Check
**Note:** SSH access must already be configured before running this automation.

```bash
# Verify SSH connection from MacBook Pro to Mac Studio
ssh username@mac-studio.local "echo 'SSH connection successful'"

# On Mac Studio via SSH - verify system specs
ssh username@mac-studio.local << 'EOF'
system_profiler SPHardwareDataType | grep -E "Model|Chip|Memory|Storage"
sw_vers -productVersion
df -g / | awk 'NR==2 {print "Available storage: " $4 "GB"}'
EOF
```

### 1.2 Install Docker and Dependencies
```bash
# Execute on Mac Studio via SSH
ssh username@mac-studio.local << 'EOF'
# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker Desktop..."
    brew install --cask docker
    echo "Please start Docker Desktop manually on Mac Studio"
    exit 1
fi

# Verify Docker is running
if ! docker info &> /dev/null; then
    echo "Docker is installed but not running. Please start Docker Desktop."
    exit 1
fi

# Install other dependencies
brew install jq git
EOF
```

## Phase 2: Docker Infrastructure Setup

### 2.1 Deploy LLM Stack on Mac Studio
```bash
# Copy repository to Mac Studio if not already there
scp -r ./frontier-llm-mac-stack username@mac-studio.local:~/

# Execute Docker setup on Mac Studio
ssh username@mac-studio.local << 'EOF'
cd ~/frontier-llm-mac-stack

# Run Docker setup script
./scripts/setup/docker-setup.sh

# Copy and configure environment
cp .env.example .env

# Update .env with Mac Studio specifics
sed -i '' "s|OLLAMA_MODELS_PATH=.*|OLLAMA_MODELS_PATH=$HOME/ollama-models|" .env
sed -i '' "s|OLLAMA_MEMORY_LIMIT=.*|OLLAMA_MEMORY_LIMIT=128G|" .env
sed -i '' "s|OLLAMA_MEMORY_RESERVATION=.*|OLLAMA_MEMORY_RESERVATION=64G|" .env

# Start all services
./start.sh

# Wait for services to be ready
sleep 30

# Verify services are running
docker compose ps
EOF
```

### 2.2 Verify Ollama Service
```bash
# Test from MacBook Pro
MAC_STUDIO_IP=$(ssh username@mac-studio.local "ipconfig getifaddr en0")
echo "Mac Studio IP: $MAC_STUDIO_IP"

# Test Ollama API
curl -s "http://${MAC_STUDIO_IP}:11434/api/version" | jq '.'

# Test Grafana
curl -s "http://${MAC_STUDIO_IP}:3000/api/health" | jq '.'
```

### 2.3 Initial Model Installation

```bash
# Pull initial model on Mac Studio
ssh username@mac-studio.local << 'EOF'
cd ~/frontier-llm-mac-stack

# Pull Qwen2.5-Coder for initial setup
./pull-model.sh qwen2.5-coder:32b-instruct-q8_0

# Verify model is loaded
docker compose exec ollama ollama list
EOF

# Test model from MacBook Pro
curl -X POST "http://${MAC_STUDIO_IP}:11434/api/generate" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-coder:32b-instruct-q8_0",
    "prompt": "Hello, are you working?",
    "stream": false
  }' | jq -r '.response'
```

### 2.4 Qwen3-235B Upgrade Path (Post-Setup)

**Important**: Only attempt after confirming the initial setup works perfectly.

```bash
# Resource requirements for Qwen3-235B:
# - Storage: ~470GB for Q8, ~235GB for Q4_K_M
# - RAM: 192GB recommended
# - Time: Several hours to download

# When ready to upgrade:
ssh username@mac-studio.local << 'EOF'
cd ~/frontier-llm-mac-stack

# Check available resources
df -g ~/ollama-models
sysctl hw.memsize | awk '{print "Total RAM: " $2/1024/1024/1024 "GB"}'

# If Qwen3-235B is available in Ollama:
# ./pull-model.sh qwen3:235b-instruct-q5_k_m

# Otherwise, see Appendix C for manual conversion
EOF
```

## Phase 3: Coding Agent Setup

### 3.1 Install Aider on MacBook Pro
```bash
# On MacBook Pro
cd ~/frontier-llm-mac-stack
./scripts/setup/05-install-aider.sh

# Update Aider config with Mac Studio IP
MAC_STUDIO_IP=$(ssh username@mac-studio.local "ipconfig getifaddr en0")
sed -i '' "s|api-base:.*|api-base: http://${MAC_STUDIO_IP}:11434|" ~/.aider.conf.yml
```

### 3.2 Install Aider on Mac Studio (Optional)
```bash
# If you want Aider directly on Mac Studio too
ssh username@mac-studio.local << 'EOF'
cd ~/frontier-llm-mac-stack
./scripts/setup/05-install-aider.sh

# Configure for local access
sed -i '' "s|api-base:.*|api-base: http://localhost:11434|" ~/.aider.conf.yml
EOF
```

### 3.3 Test Aider Integration
```bash
# Create test project on MacBook Pro
mkdir -p ~/test-llm-project
cd ~/test-llm-project
git init

echo 'def factorial(n):\n    """Calculate factorial"""\n    pass' > test.py

# Test Aider
export OLLAMA_API_BASE="http://${MAC_STUDIO_IP}:11434"
aider test.py --yes --message "Implement the factorial function"

# Verify implementation
cat test.py
```

## Phase 4: Monitoring Verification

The Docker setup includes Prometheus and Grafana. Verify they're working:

### 4.1 Access Monitoring Dashboards
```bash
# From MacBook Pro
MAC_STUDIO_IP=$(ssh username@mac-studio.local "ipconfig getifaddr en0")

# Open in browser
open "http://${MAC_STUDIO_IP}:3000"  # Grafana (admin/frontier-llm)
open "http://${MAC_STUDIO_IP}:9090"  # Prometheus

# Import dashboard via API
curl -X POST "http://admin:frontier-llm@${MAC_STUDIO_IP}:3000/api/dashboards/db" \
  -H "Content-Type: application/json" \
  -d @config/grafana/dashboards/ollama-dashboard.json
```

### 4.2 Set Up Alerts (Optional)
```bash
ssh username@mac-studio.local << 'EOF'
cd ~/frontier-llm-mac-stack

# Add alert rules to Prometheus config
cat >> config/prometheus/alert.rules.yml << 'RULES'
groups:
  - name: ollama
    rules:
      - alert: OllamaDown
        expr: up{job="ollama"} == 0
        for: 5m
        annotations:
          summary: "Ollama is down"
      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) > 0.9
        for: 10m
        annotations:
          summary: "Memory usage above 90%"
RULES

# Restart Prometheus to load rules
docker compose restart prometheus
EOF
```

## Phase 5: Integration Testing

### 5.1 Run Automated Tests
```bash
# From MacBook Pro
cd ~/frontier-llm-mac-stack
./scripts/testing/test-integration.sh

# Run benchmarks
./scripts/testing/benchmark-llm.sh qwen2.5-coder:32b-instruct-q8_0
```

### 5.2 Test Remote Development Workflow
```bash
# Create a real test project
mkdir -p ~/projects/test-ai-project
cd ~/projects/test-ai-project
git init

# Create multiple files for testing
cat > app.py << 'EOF'
# TODO: Create a Flask web application with:
# - User authentication
# - Database connection
# - REST API endpoints
EOF

cat > requirements.txt << 'EOF'
flask
sqlalchemy
EOF

# Use Aider to implement
aider app.py --message "Implement a basic Flask app with user authentication using SQLAlchemy"
```

### 5.3 Performance Validation
```bash
# Monitor resource usage during generation
ssh username@mac-studio.local << 'EOF'
docker stats --no-stream
EOF

# Check model performance metrics
curl -s "http://${MAC_STUDIO_IP}:9090/api/v1/query?query=rate(ollama_request_duration_seconds[5m])" | jq '.'
```

## Phase 6: Production Hardening

### 6.1 Configure Backup Strategy
```bash
# Set up automated backups on Mac Studio
ssh username@mac-studio.local << 'EOF'
cd ~/frontier-llm-mac-stack

# Configure backup script
sed -i '' "s|BACKUP_ROOT=.*|BACKUP_ROOT=/Volumes/Backup/frontier-llm|" scripts/backup/backup-llm-stack.sh

# Create cron job for daily backups
(crontab -l 2>/dev/null; echo "0 2 * * * cd ~/frontier-llm-mac-stack && ./scripts/backup/backup-llm-stack.sh") | crontab -

# Test backup
./scripts/backup/backup-llm-stack.sh --dry-run
EOF
```

### 6.2 Security Configuration
```bash
# Update Docker network security
ssh username@mac-studio.local << 'EOF'
cd ~/frontier-llm-mac-stack

# Update Nginx to restrict access to local network
cat > config/nginx/security.conf << 'NGINX'
# Restrict to local network only
geo $allowed_network {
    default 0;
    192.168.0.0/16 1;
    10.0.0.0/8 1;
    172.16.0.0/12 1;
    127.0.0.1 1;
}

map $allowed_network $denied {
    0 "Access denied";
    1 "";
}
NGINX

# Restart Nginx
docker compose restart nginx
EOF
```

### 6.3 Performance Tuning
```bash
# Optimize for large models
ssh username@mac-studio.local << 'EOF'
# Disable system sleep
sudo pmset -a sleep 0
sudo pmset -a disksleep 0

# Set up memory pressure monitoring
cat > ~/monitor-memory.sh << 'SCRIPT'
#!/bin/bash
while true; do
    vm_stat | grep -E "Pages free|Pages active|Pages inactive|Pages wired"
    echo "---"
    sleep 60
done
SCRIPT
chmod +x ~/monitor-memory.sh
EOF
```

## Appendix A: Coding Agent Comparison

### 1. Aider (Recommended)
- **Pros**: 
  - Native terminal integration
  - Excellent git integration
  - Supports multiple LLM backends
  - Active development
- **Cons**: 
  - Terminal-only (no GUI)
  - Limited IDE integration

### 2. Continue.dev
- **Pros**: 
  - VS Code integration
  - Multiple LLM support
  - Good for existing VS Code users
- **Cons**: 
  - Requires VS Code
  - Less flexible than Aider

### 3. Cursor
- **Pros**: 
  - Full IDE with AI integration
  - Good UX
- **Cons**: 
  - Closed source
  - Limited LLM backend options
  - Subscription model

## Appendix B: Troubleshooting

### Common Issues

1. **Ollama not accessible from MacBook Pro**
   ```bash
   # Check firewall settings
   sudo /usr/libexec/ApplicationFirewall/socketfilterfw --listapps
   
   # Test connectivity
   nc -zv mac-studio.local 11434
   ```

2. **Model loading fails**
   ```bash
   # Check available memory
   vm_stat | grep "Pages free"
   
   # Reduce model size or use smaller quantization
   ollama pull qwen2.5-coder:32b-instruct-q4_0
   ```

3. **Slow response times**
   ```bash
   # Check GPU acceleration
   system_profiler SPDisplaysDataType | grep "Metal"
   
   # Monitor resource usage
   sudo powermetrics --samplers gpu_power -i 1000 -n 10
   ```

## Appendix C: Qwen3-235B Manual Installation

If Qwen3-235B is not available through Ollama, manual conversion is required:

### C.1 Preparation
```bash
ssh username@mac-studio.local << 'EOF'
# Install conversion tools
brew install python@3.11
pip3 install transformers accelerate safetensors

# Clone llama.cpp for GGUF conversion
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
make -j

# Verify CUDA/Metal support
./main --help | grep -i metal
EOF
```

### C.2 Model Download and Conversion
```bash
# WARNING: This requires ~500GB+ free space and significant bandwidth
ssh username@mac-studio.local << 'EOF'
# Create workspace
mkdir -p ~/models/qwen3-235b
cd ~/models/qwen3-235b

# Download from HuggingFace (example - adjust for actual source)
# python3 -c "from transformers import AutoModelForCausalLM; \
#   model = AutoModelForCausalLM.from_pretrained('Qwen/Qwen3-235B', \
#   cache_dir='./cache', resume_download=True)"

# Convert to GGUF format
# python3 ~/llama.cpp/convert.py . \
#   --outfile qwen3-235b-f16.gguf \
#   --outtype f16

# Quantize for efficiency (Q5_K_M recommended for quality/size balance)
# ~/llama.cpp/quantize qwen3-235b-f16.gguf qwen3-235b-q5_k_m.gguf Q5_K_M

# Create Ollama Modelfile
cat > Modelfile << 'MODELFILE'
FROM ./qwen3-235b-q5_k_m.gguf

PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.1
PARAMETER stop "<|endoftext|>"

SYSTEM "You are a helpful AI coding assistant."
MODELFILE

# Import to Ollama
# docker compose exec ollama ollama create qwen3:235b-q5_k_m -f Modelfile
EOF
```

### C.3 Verify Installation
```bash
# Test the model
curl -X POST "http://${MAC_STUDIO_IP}:11434/api/generate" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3:235b-q5_k_m",
    "prompt": "Explain quantum computing in simple terms",
    "stream": false
  }' | jq -r '.response'

# Update Aider configuration
sed -i '' 's/qwen2.5-coder:32b/qwen3:235b-q5_k_m/g' ~/.aider.conf.yml
```

## Final Notes

### Success Criteria
- All Docker services running and accessible
- Ollama responding to API calls from MacBook Pro
- Aider successfully using remote Ollama instance
- Monitoring dashboards showing system metrics
- Backup strategy implemented and tested

### Post-Setup Recommendations
1. Run the system with Qwen2.5-Coder for at least a week before upgrading
2. Monitor resource usage patterns to plan for Qwen3-235B
3. Test backup and restore procedures
4. Document any network-specific configurations needed

### Scaling Considerations
- Qwen3-235B will require ~5-10x more resources
- Consider dedicated GPU for acceleration (via eGPU if needed)
- Plan for 1TB+ NVMe storage for multiple large models
- Implement model caching strategies for faster switching

### Troubleshooting Resources
- Logs: `docker compose logs -f [service]`
- Metrics: Grafana dashboards at port 3000
- Community: Ollama Discord and GitHub issues
- Benchmarks: Use included scripts to validate performance