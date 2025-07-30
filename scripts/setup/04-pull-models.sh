#!/bin/bash
set -euo pipefail

# 04-pull-models.sh - Download and configure Ollama models
# This script handles model downloads with progress tracking and verification

echo "=== Ollama Model Management ==="

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

# Check if Ollama is running
check_ollama() {
    if ! curl -s http://localhost:11434/api/version > /dev/null 2>&1; then
        print_error "Ollama is not running. Starting Ollama service..."
        
        # Try to start using our service helper
        if [[ -x ~/bin/ollama-service ]]; then
            ~/bin/ollama-service start
            sleep 5
        else
            ollama serve > /tmp/ollama.log 2>&1 &
            sleep 5
        fi
        
        # Check again
        if ! curl -s http://localhost:11434/api/version > /dev/null 2>&1; then
            print_error "Failed to start Ollama service"
            exit 1
        fi
    fi
    print_status "Ollama service is running"
}

# Function to format bytes to human readable
format_bytes() {
    local bytes=$1
    if (( bytes < 1024 )); then
        echo "${bytes}B"
    elif (( bytes < 1048576 )); then
        echo "$((bytes / 1024))KB"
    elif (( bytes < 1073741824 )); then
        echo "$((bytes / 1048576))MB"
    else
        echo "$((bytes / 1073741824))GB"
    fi
}

# Function to get model size estimate
get_model_size() {
    local model=$1
    case "$model" in
        *"70b"*|*"72b"*) echo "~140GB" ;;
        *"34b"*|*"32b"*) echo "~65GB" ;;
        *"13b"*) echo "~26GB" ;;
        *"7b"*|*"8b"*) echo "~14GB" ;;
        *"3b"*) echo "~6GB" ;;
        *":q4"*) echo "(Q4 quantization)" ;;
        *":q8"*) echo "(Q8 quantization)" ;;
        *) echo "size varies" ;;
    esac
}

# List available models
list_models() {
    print_header "Currently Installed Models"
    
    if ollama list 2>/dev/null | grep -q "NAME"; then
        ollama list
    else
        print_warning "No models currently installed"
    fi
    
    print_header "Popular Models for Coding"
    cat << EOF
1. qwen2.5-coder:32b-instruct-q8_0  - Excellent coding model (${get_model_size "32b"})
2. qwen2.5-coder:32b-instruct-q4_0  - Smaller quantization (${get_model_size "32b:q4"})
3. codellama:34b                     - Meta's code model (${get_model_size "34b"})
4. codellama:13b                     - Smaller CodeLlama (${get_model_size "13b"})
5. deepseek-coder:33b               - Code-focused model (${get_model_size "33b"})
6. llama2:13b                       - General purpose (${get_model_size "13b"})
7. mixtral:8x7b                     - MoE architecture (${get_model_size "47b"})

For testing with smaller models:
- qwen2.5-coder:7b                  - Compact coding model (${get_model_size "7b"})
- codellama:7b                      - Small CodeLlama (${get_model_size "7b"})
EOF
}

# Pull a model with progress tracking
pull_model() {
    local model=$1
    print_header "Pulling Model: $model"
    
    # Check available space
    local available_gb=$(df -g ~ | awk 'NR==2 {print $4}')
    print_status "Available disk space: ${available_gb}GB"
    
    # Estimate model size and warn if low space
    local size_est=$(get_model_size "$model")
    print_status "Estimated model size: $size_est"
    
    if [[ $available_gb -lt 50 ]]; then
        print_warning "Low disk space! Large models may fail to download"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Download cancelled"
            return
        fi
    fi
    
    # Start the pull
    print_status "Starting download... This may take a while depending on model size and connection speed"
    
    # Run ollama pull and capture output
    if ollama pull "$model"; then
        print_status "Successfully pulled model: $model"
        
        # Show model info
        print_header "Model Information"
        ollama show "$model" --modelfile 2>/dev/null || true
    else
        print_error "Failed to pull model: $model"
        return 1
    fi
}

# Test a model
test_model() {
    local model=$1
    print_header "Testing Model: $model"
    
    print_status "Sending test prompt..."
    
    # Create a simple test prompt
    local response=$(curl -s -X POST http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d '{
            "model": "'"$model"'",
            "prompt": "Write a Python function that returns the fibonacci sequence up to n terms",
            "stream": false
        }' | jq -r '.response' 2>/dev/null)
    
    if [[ -n "$response" ]]; then
        print_status "Model responded successfully!"
        echo -e "\nResponse preview:"
        echo "$response" | head -10
        echo "..."
    else
        print_error "Model did not respond or error occurred"
    fi
}

# Delete a model
delete_model() {
    local model=$1
    print_warning "Are you sure you want to delete $model? (y/N)"
    read -p "" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ollama rm "$model"
        print_status "Model deleted: $model"
    else
        print_status "Deletion cancelled"
    fi
}

# Main menu
show_menu() {
    while true; do
        print_header "Ollama Model Manager"
        echo "1) List installed models"
        echo "2) Pull a model"
        echo "3) Test a model"
        echo "4) Delete a model"
        echo "5) Pull recommended coding model"
        echo "6) Check system resources"
        echo "q) Quit"
        echo
        read -p "Select an option: " choice
        
        case $choice in
            1)
                list_models
                ;;
            2)
                read -p "Enter model name (e.g., qwen2.5-coder:32b): " model_name
                if [[ -n "$model_name" ]]; then
                    pull_model "$model_name"
                fi
                ;;
            3)
                ollama list 2>/dev/null | tail -n +2 | awk '{print NR") " $1}'
                read -p "Select model number to test: " model_num
                model_name=$(ollama list 2>/dev/null | tail -n +2 | awk "NR==$model_num {print \$1}")
                if [[ -n "$model_name" ]]; then
                    test_model "$model_name"
                fi
                ;;
            4)
                ollama list 2>/dev/null | tail -n +2 | awk '{print NR") " $1}'
                read -p "Select model number to delete: " model_num
                model_name=$(ollama list 2>/dev/null | tail -n +2 | awk "NR==$model_num {print \$1}")
                if [[ -n "$model_name" ]]; then
                    delete_model "$model_name"
                fi
                ;;
            5)
                print_status "Pulling recommended model for coding..."
                pull_model "qwen2.5-coder:32b-instruct-q8_0"
                ;;
            6)
                print_header "System Resources"
                echo "Disk Space:"
                df -h ~ | grep -E "Filesystem|$HOME"
                echo
                echo "Memory:"
                if command -v vm_stat &> /dev/null; then
                    vm_stat | grep -E "free:|active:|inactive:|wired:"
                fi
                echo
                echo "Ollama Models Location:"
                du -sh ~/ollama-models 2>/dev/null || echo "Models directory not found"
                ;;
            q|Q)
                print_status "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option"
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Script can be run with arguments or interactively
if [[ $# -eq 0 ]]; then
    # Interactive mode
    check_ollama
    show_menu
else
    # Command line mode
    check_ollama
    case "$1" in
        list)
            list_models
            ;;
        pull)
            if [[ -n "${2:-}" ]]; then
                pull_model "$2"
            else
                print_error "Please specify a model name"
                exit 1
            fi
            ;;
        test)
            if [[ -n "${2:-}" ]]; then
                test_model "$2"
            else
                print_error "Please specify a model name"
                exit 1
            fi
            ;;
        delete|rm)
            if [[ -n "${2:-}" ]]; then
                delete_model "$2"
            else
                print_error "Please specify a model name"
                exit 1
            fi
            ;;
        *)
            print_error "Unknown command: $1"
            echo "Usage: $0 [list|pull|test|delete] [model_name]"
            exit 1
            ;;
    esac
fi