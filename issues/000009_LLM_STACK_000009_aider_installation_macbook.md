# Step 9: Aider Installation on MacBook Pro

## Overview
Install and configure Aider on the MacBook Pro to use the remote Ollama instance on Mac Studio. This enables AI-assisted coding using the self-hosted LLM.

## Tasks
1. Install Aider via pip
2. Configure Aider to use remote Ollama API
3. Set up Aider configuration file
4. Test Aider with remote LLM
5. Configure git integration

## Implementation Details

### 1. Aider Installation Script
Update `scripts/setup/05-install-aider.sh` to be more robust:
```bash
#!/bin/bash
set -euo pipefail

echo "Installing Aider on MacBook Pro..."

# Check Python version
python_version=$(python3 --version | cut -d' ' -f2)
echo "Python version: $python_version"

# Create virtual environment (recommended)
if [[ ! -d "$HOME/.aider-env" ]]; then
    python3 -m venv "$HOME/.aider-env"
fi

# Activate and install
source "$HOME/.aider-env/bin/activate"
pip install --upgrade pip
pip install aider-chat

# Create shell alias
echo 'alias aider="$HOME/.aider-env/bin/aider"' >> ~/.zshrc

# Get Mac Studio IP
read -p "Enter Mac Studio IP address or hostname: " MAC_STUDIO_HOST
```

### 2. Aider Configuration
Create `~/.aider.conf.yml`:
```yaml
# Ollama configuration
model: ollama/qwen2.5-coder:32b-instruct-q8_0
api-base: http://MAC_STUDIO_HOST:11434

# Editor and display
edit-format: diff
pretty: true
stream: true

# Git settings
auto-commits: false
commit-prompt: |
  Write a clear, concise commit message for these changes.
  Follow conventional commits format.

# Context window
map-tokens: 2048
max-chat-history-tokens: 4096

# Code analysis
show-diffs: true
show-repo-map: true

# Safety
check-update: true
```

### 3. Shell Integration
Create helper functions in `~/.zshrc`:
```bash
# Aider with project defaults
aider-project() {
    local project_dir="${1:-.}"
    cd "$project_dir"
    aider --yes-always --auto-commits
}

# Aider with specific model
aider-model() {
    local model="${1:-qwen2.5-coder:32b-instruct-q8_0}"
    aider --model "ollama/$model"
}

# Check Ollama status
ollama-status() {
    curl -s "http://${MAC_STUDIO_HOST:-mac-studio.local}:11434/api/version" | jq .
}
```

### 4. Test Script
Create `scripts/testing/test-aider-remote.sh`:
```bash
#!/bin/bash
# Test Aider with remote Ollama

# Create test project
mkdir -p /tmp/aider-test
cd /tmp/aider-test
git init

# Create test file
cat > test.py << 'EOF'
def calculate_area(radius):
    """Calculate the area of a circle"""
    pass
EOF

# Test Aider
aider test.py --message "Implement the calculate_area function"

# Verify changes
cat test.py
```

## Dependencies
- Step 8: Model successfully pulled
- Python 3.8+ installed on MacBook Pro
- Git configured on MacBook Pro

## Success Criteria
- Aider installed and accessible via command line
- Successfully connects to remote Ollama
- Can modify code files using AI assistance
- Git integration works properly
- Response time acceptable over network

## Testing
```bash
# Check installation
aider --version

# Test connection
aider --model ollama/qwen2.5-coder:32b-instruct-q8_0 --api-base http://mac-studio.local:11434 --no-files

# Test code modification
cd ~/test-project
aider main.py --message "Add error handling to the main function"
```

## Notes
- Consider network latency impact on streaming responses
- Aider caches some data locally for performance
- Can use SSH tunnel for secure remote access
- Multiple developers can share the same Ollama instance