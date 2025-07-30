#!/bin/bash
set -euo pipefail

# 02-install-ollama.sh - Install and configure Ollama for Mac Studio
# This script installs Ollama and sets it up for network access

echo "=== Installing Ollama LLM Server ==="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    print_error "This script is designed for macOS only"
    exit 1
fi

# Install Ollama
print_status "Installing Ollama..."
if ! command -v ollama &> /dev/null; then
    curl -fsSL https://ollama.com/install.sh | sh
    
    # Wait for installation to complete
    sleep 2
    
    # Verify installation
    if command -v ollama &> /dev/null; then
        print_status "Ollama installed successfully"
        ollama --version
    else
        print_error "Ollama installation failed"
        exit 1
    fi
else
    print_status "Ollama already installed"
    ollama --version
fi

# Configure Ollama environment variables
print_status "Configuring Ollama for network access..."

# Add environment variables to .zshrc if not already present
if ! grep -q "OLLAMA_HOST" ~/.zshrc; then
    cat >> ~/.zshrc << 'EOF'

# Ollama configuration
export OLLAMA_HOST="0.0.0.0:11434"
export OLLAMA_MODELS="$HOME/ollama-models"
export OLLAMA_KEEP_ALIVE="10m"
export OLLAMA_NUM_PARALLEL="4"
EOF
    print_status "Added Ollama environment variables to ~/.zshrc"
else
    print_status "Ollama environment variables already configured"
fi

# Create models directory
if [[ ! -d "$HOME/ollama-models" ]]; then
    mkdir -p "$HOME/ollama-models"
    print_status "Created models directory at ~/ollama-models"
else
    print_status "Models directory already exists"
fi

# Create Ollama configuration directory
mkdir -p ~/.ollama

# Create Ollama config file
print_status "Creating Ollama configuration file..."
cat > ~/.ollama/config.json << 'EOF'
{
  "host": "0.0.0.0:11434",
  "models_path": "~/ollama-models",
  "keep_alive": "10m",
  "num_parallel": 4,
  "max_loaded_models": 2,
  "gpu_layers": -1,
  "cpu_threads": 0,
  "flash_attention": true
}
EOF

# Check available storage
print_status "Checking available storage..."
available_space=$(df -h "$HOME" | awk 'NR==2 {print $4}')
print_status "Available space in home directory: $available_space"

# Get storage size in GB
available_gb=$(df -g "$HOME" | awk 'NR==2 {print $4}')
if [[ $available_gb -lt 100 ]]; then
    print_warning "Less than 100GB available. Large models may require more space."
fi

# Source the environment variables
export OLLAMA_HOST="0.0.0.0:11434"
export OLLAMA_MODELS="$HOME/ollama-models"

# Start Ollama service temporarily to test
print_status "Starting Ollama service for testing..."
ollama serve > /tmp/ollama.log 2>&1 &
OLLAMA_PID=$!

# Wait for service to start
sleep 5

# Test if Ollama is running
if curl -s http://localhost:11434/api/version > /dev/null; then
    print_status "Ollama service is running successfully"
    print_status "API endpoint: http://localhost:11434"
else
    print_error "Failed to start Ollama service"
    print_error "Check logs at /tmp/ollama.log"
    kill $OLLAMA_PID 2>/dev/null || true
    exit 1
fi

# Stop the test service
kill $OLLAMA_PID 2>/dev/null || true
print_status "Stopped test service"

print_status "Ollama installation complete!"
print_status "Next steps:"
print_status "1. Run: source ~/.zshrc"
print_status "2. Run: ./03-configure-ollama-service.sh to set up auto-start"
print_status "3. Run: ./04-pull-models.sh to download models"