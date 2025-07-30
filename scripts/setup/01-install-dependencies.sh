#!/bin/bash
set -euo pipefail

# 01-install-dependencies.sh - Install core dependencies for LLM stack
# This script installs Homebrew and required packages for the Mac Studio

echo "=== Installing Core Dependencies for LLM Stack ==="

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

# Install Homebrew if not present
if ! command -v brew &> /dev/null; then
    print_status "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    print_status "Homebrew already installed"
fi

# Update Homebrew
print_status "Updating Homebrew..."
brew update

# Install required packages
print_status "Installing required packages..."
packages=(
    "wget"
    "curl"
    "git"
    "python@3.12"
    "node@20"
    "jq"
    "ripgrep"
    "htop"
)

for package in "${packages[@]}"; do
    if brew list "$package" &> /dev/null; then
        print_status "$package already installed"
    else
        print_status "Installing $package..."
        brew install "$package"
    fi
done

# Install cask packages
print_status "Installing Docker Desktop..."
if ! brew list --cask docker &> /dev/null; then
    brew install --cask docker
else
    print_status "Docker Desktop already installed"
fi

# Install Xcode Command Line Tools
print_status "Checking Xcode Command Line Tools..."
if ! xcode-select -p &> /dev/null; then
    print_status "Installing Xcode Command Line Tools..."
    xcode-select --install
    print_warning "Please complete the Xcode Command Line Tools installation in the popup window"
    print_warning "Re-run this script after installation is complete"
    exit 0
else
    print_status "Xcode Command Line Tools already installed"
fi

# Create required directories
print_status "Creating project directories..."
mkdir -p ~/bin
mkdir -p ~/ollama-models

# Add ~/bin to PATH if not already there
if ! echo "$PATH" | grep -q "$HOME/bin"; then
    echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
    print_status "Added ~/bin to PATH"
fi

print_status "Core dependencies installation complete!"
print_status "Please run: source ~/.zshrc"