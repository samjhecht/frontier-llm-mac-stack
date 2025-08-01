#!/bin/bash
set -euo pipefail

# 05-install-aider.sh - Install and configure Aider for AI pair programming
# This script sets up Aider to work with the local Ollama instance

echo "=== Installing Aider AI Pair Programming Tool ==="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

# Check Python installation
print_header "Checking Python Installation"
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is not installed. Please run 01-install-dependencies.sh first"
    exit 1
fi

python_version=$(python3 --version | cut -d' ' -f2)
print_status "Python version: $python_version"

# Check if pip is available
if ! command -v pip3 &> /dev/null; then
    print_error "pip3 is not installed"
    print_status "Installing pip..."
    python3 -m ensurepip --default-pip
fi

# Install or upgrade Aider
print_header "Installing Aider"
if pip3 show aider-chat &> /dev/null; then
    print_status "Aider is already installed, upgrading..."
    pip3 install --upgrade aider-chat
else
    print_status "Installing Aider..."
    pip3 install aider-chat
fi

# Verify installation
if ! command -v aider &> /dev/null; then
    print_warning "Aider command not found in PATH"
    print_status "You may need to add Python bin directory to PATH"
    print_status "Add this to your ~/.zshrc:"
    echo 'export PATH="$HOME/.local/bin:$PATH"'
    
    # Try to add it for current session
    export PATH="$HOME/.local/bin:$PATH"
fi

# Get Aider version
if command -v aider &> /dev/null; then
    aider_version=$(aider --version 2>&1 | head -1)
    print_status "Aider installed: $aider_version"
else
    print_error "Failed to verify Aider installation"
fi

# Create Aider configuration directory
print_header "Configuring Aider"
mkdir -p ~/.config/aider

# Detect Ollama host
OLLAMA_HOST="localhost"
if [[ -n "${OLLAMA_API_BASE:-}" ]]; then
    OLLAMA_HOST=$(echo "$OLLAMA_API_BASE" | sed -E 's|https?://([^:/]+).*|\1|')
elif ping -c 1 -W 1 mac-studio.local &> /dev/null; then
    OLLAMA_HOST="mac-studio.local"
    print_status "Detected Mac Studio at mac-studio.local"
fi

# Create Aider configuration file
print_status "Creating Aider configuration..."
cat > ~/.aider.conf.yml << EOF
# Aider configuration for Ollama integration

# Model settings
model: ollama/qwen2.5-coder:32b-instruct-q8_0
weak-model: ollama/qwen2.5-coder:7b
editor-model: ollama/qwen2.5-coder:32b-instruct-q8_0

# API configuration
ollama-api-base: http://${OLLAMA_HOST}:11434

# Editor settings
edit-format: diff
editor-edit-format: diff

# Git settings
auto-commits: false
commit: false
dry-run: false

# UI settings
pretty: true
stream: true
user-input-color: blue
tool-output-color: green
tool-error-color: red
assistant-output-color: yellow
code-theme: monokai

# Context window
map-tokens: 2048
max-chat-history-tokens: 8192

# File handling
read-only: false
encoding: utf-8
gitignore: true

# Voice settings (optional)
voice-language: en
EOF

# Create shell aliases and functions
print_status "Creating shell helpers..."
cat >> ~/.zshrc << 'EOF'

# Aider helpers
alias aider-local='aider --ollama-api-base http://localhost:11434'
alias aider-remote='aider --ollama-api-base http://mac-studio.local:11434'
alias aider-small='aider --model ollama/qwen2.5-coder:7b'

# Function to start Aider with project-specific settings
aider-project() {
    local project_dir="${1:-.}"
    local model="${2:-ollama/qwen2.5-coder:32b-instruct-q8_0}"
    
    echo "Starting Aider in $project_dir with model $model"
    cd "$project_dir" && aider --model "$model"
}

# Function to list available Ollama models for Aider
aider-models() {
    echo "Available Ollama models for Aider:"
    curl -s http://${OLLAMA_HOST:-localhost}:11434/api/tags | jq -r '.models[].name' 2>/dev/null || echo "Could not fetch models"
}
EOF

# Create example configurations for different use cases
print_header "Creating Example Configurations"

# Configuration for small projects
cat > ~/.config/aider/small-project.yml << 'EOF'
# Configuration for small projects or quick edits
model: ollama/qwen2.5-coder:7b
map-tokens: 1024
max-chat-history-tokens: 4096
auto-commits: true
EOF

# Configuration for large projects
cat > ~/.config/aider/large-project.yml << 'EOF'
# Configuration for large projects
model: ollama/qwen2.5-coder:32b-instruct-q8_0
map-tokens: 4096
max-chat-history-tokens: 16384
auto-commits: false
show-diffs: true
EOF

# Configuration for code reviews
cat > ~/.config/aider/code-review.yml << 'EOF'
# Configuration for code reviews
model: ollama/qwen2.5-coder:32b-instruct-q8_0
read-only: true
auto-commits: false
show-diffs: true
pretty: true
EOF

# Create a test script
print_status "Creating Aider test script..."
cat > ~/bin/test-aider << 'EOF'
#!/bin/bash
# Test Aider connection to Ollama

echo "Testing Aider + Ollama integration..."

# Check Ollama availability
OLLAMA_HOST="${OLLAMA_HOST:-localhost}"
if curl -s "http://${OLLAMA_HOST}:11434/api/version" > /dev/null; then
    echo "✓ Ollama is accessible at ${OLLAMA_HOST}:11434"
else
    echo "✗ Cannot connect to Ollama at ${OLLAMA_HOST}:11434"
    exit 1
fi

# Create a temporary test project
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
git init

# Create a test file
cat > test.py << 'PYTHON'
def hello():
    return "Hello, World!"
PYTHON

# Test Aider
echo "Testing Aider with a simple task..."
echo "Write a greeting function that returns 'Hello, World!'" | aider test.py --yes --no-auto-commits

# Check if Aider modified the file
if grep -q "Hello, World!" test.py; then
    echo "✓ Aider successfully modified the code"
    cat test.py
else
    echo "✗ Aider did not modify the code as expected"
fi

# Cleanup
cd - > /dev/null
rm -rf "$TEST_DIR"
EOF

chmod +x ~/bin/test-aider

# Create VS Code integration script
print_status "Creating VS Code integration..."
cat > ~/.config/aider/vscode-integration.md << 'EOF'
# VS Code Integration with Aider

## Setup VS Code Terminal Integration

1. Open VS Code settings (Cmd+,)
2. Search for "terminal.integrated.env"
3. Add environment variables:
   ```json
   "terminal.integrated.env.osx": {
       "OLLAMA_API_BASE": "http://localhost:11434"
   }
   ```

## Create VS Code Task

1. Create `.vscode/tasks.json` in your project:
   ```json
   {
       "version": "2.0.0",
       "tasks": [
           {
               "label": "Aider - Current File",
               "type": "shell",
               "command": "aider",
               "args": ["${file}"],
               "presentation": {
                   "reveal": "always",
                   "panel": "new"
               }
           },
           {
               "label": "Aider - Project",
               "type": "shell",
               "command": "aider",
               "presentation": {
                   "reveal": "always",
                   "panel": "new"
               }
           }
       ]
   }
   ```

## Keyboard Shortcuts

Add to `keybindings.json`:
```json
[
    {
        "key": "cmd+shift+a",
        "command": "workbench.action.tasks.runTask",
        "args": "Aider - Current File"
    }
]
```
EOF

# Display usage instructions
print_header "Installation Complete!"

cat << EOF
Aider has been installed and configured to work with your Ollama instance.

Quick Start:
  aider                     # Start Aider in current directory
  aider-project /path/to/project  # Start in specific project
  aider-models              # List available models
  test-aider               # Test the integration

Configuration files created:
  ~/.aider.conf.yml        # Main configuration
  ~/.config/aider/         # Additional configurations

Aliases available:
  aider-local             # Use local Ollama instance
  aider-remote            # Use remote Mac Studio instance
  aider-small             # Use smaller, faster model

Example usage:
  # Basic usage
  aider myfile.py

  # With specific model
  aider --model ollama/codellama:13b myfile.py

  # Read-only mode for code review
  aider --read-only --show-diffs .

  # Use configuration profile
  aider --config ~/.config/aider/code-review.yml

Note: Run 'source ~/.zshrc' to load the new aliases
EOF

print_warning "Remember to have Ollama running with a model loaded before using Aider!"