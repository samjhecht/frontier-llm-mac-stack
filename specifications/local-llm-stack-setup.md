# Self-Hosted LLM with Coding Agent: Complete Implementation Plan

## Executive Summary

This document provides a comprehensive implementation plan for setting up a self-hosted LLM (Qwen3-235B) on a Mac Studio with an alternative coding agent to replace Claude Code. The solution includes remote access from a MacBook Pro, observability setup, and detailed step-by-step instructions.

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

### 1.1 System Requirements Verification
```bash
# On Mac Studio - verify system specs
system_profiler SPHardwareDataType | grep -E "Model|Chip|Memory|Storage"
sw_vers -productVersion

# Check available storage (need ~500GB free)
df -h /
```

### 1.2 Install Core Dependencies
```bash
# Install Homebrew if not present
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required packages
brew install wget curl git python@3.12 node@20
brew install --cask docker

# Install development tools
xcode-select --install
```

### 1.3 Configure SSH Access
```bash
# On Mac Studio - enable SSH
sudo systemsetup -setremotelogin on

# Generate SSH keys if needed
ssh-keygen -t ed25519 -C "llm-server@macstudio"

# On MacBook Pro - copy SSH key
ssh-copy-id -i ~/.ssh/id_ed25519.pub username@mac-studio.local
```

## Phase 2: LLM Infrastructure Setup

### 2.1 Install Ollama
```bash
# On Mac Studio
curl -fsSL https://ollama.com/install.sh | sh

# Verify installation
ollama --version

# Configure Ollama for network access
echo 'export OLLAMA_HOST="0.0.0.0:11434"' >> ~/.zshrc
echo 'export OLLAMA_MODELS="/Users/$USER/ollama-models"' >> ~/.zshrc
source ~/.zshrc

# Create models directory with sufficient space
mkdir -p ~/ollama-models
```

### 2.2 Configure Ollama Service
```bash
# Create launchd service for auto-start
cat << 'EOF' > ~/Library/LaunchAgents/com.ollama.server.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ollama.server</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/ollama</string>
        <string>serve</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>EnvironmentVariables</key>
    <dict>
        <key>OLLAMA_HOST</key>
        <string>0.0.0.0:11434</string>
        <key>OLLAMA_MODELS</key>
        <string>/Users/USERNAME/ollama-models</string>
    </dict>
</dict>
</plist>
EOF

# Replace USERNAME with actual username
sed -i '' "s/USERNAME/$USER/g" ~/Library/LaunchAgents/com.ollama.server.plist

# Load the service
launchctl load ~/Library/LaunchAgents/com.ollama.server.plist
```

### 2.3 Model Installation and Configuration

**Note**: Qwen3-235B requires extensive resources. Alternative approach using Qwen2.5-Coder-32B recommended for initial setup.

```bash
# Option A: Qwen2.5-Coder-32B (Recommended for testing)
ollama pull qwen2.5-coder:32b-instruct-q8_0

# Create model switching script
cat << 'EOF' > ~/bin/switch-model.sh
#!/bin/bash
MODEL=$1
if [ -z "$MODEL" ]; then
    echo "Usage: switch-model.sh <model-name>"
    echo "Available models:"
    ollama list
    exit 1
fi
echo "export OLLAMA_MODEL=$MODEL" > ~/.ollama-model
source ~/.ollama-model
echo "Switched to model: $MODEL"
EOF

chmod +x ~/bin/switch-model.sh
```

## Phase 3: Coding Agent Installation

### 3.1 Install Aider (Recommended)
```bash
# On both Mac Studio and MacBook Pro
pip install aider-chat

# Configure Aider for Ollama
cat << 'EOF' > ~/.aider.conf.yml
model: ollama/qwen2.5-coder:32b-instruct-q8_0
api-base: http://mac-studio.local:11434
edit-format: diff
auto-commits: false
pretty: true
stream: true
EOF
```

### 3.2 Test Aider Connection
```bash
# From MacBook Pro
export OLLAMA_API_BASE="http://mac-studio.local:11434"
aider --model ollama/qwen2.5-coder:32b-instruct-q8_0 --no-auto-commits
```

## Phase 4: Observability Setup

### 4.1 Install Monitoring Stack
```bash
# On Mac Studio
brew install prometheus grafana

# Configure Prometheus
cat << 'EOF' > /usr/local/etc/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'ollama'
    static_configs:
      - targets: ['localhost:11434']
    metrics_path: '/api/metrics'
  
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
EOF

# Install node exporter for system metrics
brew install node_exporter
```

### 4.2 Create Monitoring Dashboard
```bash
# Start services
brew services start prometheus
brew services start grafana
brew services start node_exporter

# Create Ollama monitoring script
cat << 'EOF' > ~/bin/monitor-ollama.sh
#!/bin/bash
while true; do
    echo "=== Ollama Status ==="
    curl -s http://localhost:11434/api/ps | jq '.'
    echo ""
    echo "=== System Resources ==="
    top -l 1 -n 0 | grep -E "CPU|PhysMem|GPU"
    echo ""
    sleep 5
done
EOF

chmod +x ~/bin/monitor-ollama.sh
```

### 4.3 Configure Grafana Dashboard
```bash
# Access Grafana at http://mac-studio.local:3000
# Default credentials: admin/admin

# Import dashboard configuration
cat << 'EOF' > ~/ollama-dashboard.json
{
  "dashboard": {
    "title": "Ollama LLM Monitoring",
    "panels": [
      {
        "title": "Model Response Time",
        "targets": [{"expr": "rate(ollama_request_duration_seconds[5m])"}]
      },
      {
        "title": "GPU Usage",
        "targets": [{"expr": "node_gpu_utilization"}]
      },
      {
        "title": "Memory Usage",
        "targets": [{"expr": "node_memory_active_bytes"}]
      }
    ]
  }
}
EOF
```

## Phase 5: Integration and Testing

### 5.1 Create Test Environment
```bash
# On MacBook Pro
mkdir ~/llm-test-project
cd ~/llm-test-project
git init

# Create test file
cat << 'EOF' > test.py
def fibonacci(n):
    """Calculate fibonacci number"""
    # TODO: Implement this function
    pass

if __name__ == "__main__":
    print(fibonacci(10))
EOF
```

### 5.2 Test Aider Integration
```bash
# Start Aider session
aider test.py

# In Aider prompt, test:
# "Implement the fibonacci function using dynamic programming"
```

### 5.3 Performance Benchmarking
```bash
# Create benchmark script
cat << 'EOF' > ~/bin/benchmark-llm.sh
#!/bin/bash
echo "Testing LLM response time..."
time curl -X POST http://mac-studio.local:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-coder:32b-instruct-q8_0",
    "prompt": "Write a Python function to sort a list",
    "stream": false
  }'
EOF

chmod +x ~/bin/benchmark-llm.sh
```

## Phase 6: Production Configuration

### 6.1 Security Hardening
```bash
# Configure firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/local/bin/ollama
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --block all
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --allow /usr/local/bin/ollama

# Restrict Ollama to local network only
cat << 'EOF' > ~/ollama-nginx.conf
server {
    listen 11434;
    server_name mac-studio.local;
    
    location / {
        if ($remote_addr !~ ^192\.168\.) {
            return 403;
        }
        proxy_pass http://localhost:11434;
    }
}
EOF
```

### 6.2 Backup and Recovery
```bash
# Create backup script
cat << 'EOF' > ~/bin/backup-llm.sh
#!/bin/bash
BACKUP_DIR="/Volumes/Backup/llm-backups/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Backup models
rsync -av ~/ollama-models/ "$BACKUP_DIR/models/"

# Backup configurations
tar -czf "$BACKUP_DIR/configs.tar.gz" \
  ~/.ollama* \
  ~/.aider* \
  ~/Library/LaunchAgents/com.ollama.server.plist
EOF

chmod +x ~/bin/backup-llm.sh
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

## Appendix C: Model Conversion for Qwen3-235B

Due to the size of Qwen3-235B, special handling is required:

```bash
# This is a placeholder - actual implementation would require:
# 1. Downloading the original model (likely in safetensors format)
# 2. Converting to GGUF format using llama.cpp
# 3. Creating appropriate quantization (likely Q4_K_M or Q5_K_M)
# 4. Creating custom Modelfile for Ollama

# The process would look like:
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
make

# Download model files (would require significant bandwidth)
# Convert and quantize
# Import to Ollama
```

## Final Notes

This setup provides a robust, self-hosted LLM environment with coding assistance capabilities. The Mac Studio's M3 Ultra chip provides excellent performance for running large language models locally. Start with the smaller Qwen2.5-Coder model for testing, then scale up to larger models as needed.

Key success factors:
- Ensure adequate cooling for sustained workloads
- Monitor memory usage carefully with large models
- Use quantization appropriately to balance quality and performance
- Regular backups of model files and configurations