#!/bin/bash

# Validate environment variables

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if a variable is set and not empty
check_env_var() {
    local var_name=$1
    local var_value="${!var_name}"
    local required=${2:-false}
    
    if [ -z "$var_value" ]; then
        if [ "$required" = "true" ]; then
            echo -e "${RED}[ERROR]${NC} Required variable $var_name is not set"
            return 1
        else
            echo -e "${YELLOW}[WARNING]${NC} Optional variable $var_name is not set"
        fi
    else
        echo -e "${GREEN}[OK]${NC} $var_name is set"
    fi
    return 0
}

# Function to validate paths
check_path() {
    local path_var=$1
    local path_value="${!path_var}"
    
    if [ -n "$path_value" ]; then
        if [ ! -e "$path_value" ]; then
            echo -e "${YELLOW}[WARNING]${NC} Path $path_value (from $path_var) does not exist"
        else
            echo -e "${GREEN}[OK]${NC} Path $path_value exists"
        fi
    fi
}

echo "Validating environment variables..."

# Load .env files if they exist
if [ -f "$ROOT_DIR/.env" ]; then
    set -a
    source "$ROOT_DIR/.env"
    set +a
fi

# Check common variables
check_env_var "GRAFANA_ADMIN_USER"
check_env_var "GRAFANA_ADMIN_PASSWORD"

# Check if password is still the default
if [ "$GRAFANA_ADMIN_PASSWORD" = "changeme123!" ] || [ "$GRAFANA_ADMIN_PASSWORD" = "frontier-llm" ]; then
    echo -e "${YELLOW}[WARNING]${NC} GRAFANA_ADMIN_PASSWORD is using the default value. Please change it for production."
fi

# Check stack-specific variables based on current stack
if [ -f "$ROOT_DIR/.current-stack" ]; then
    CURRENT_STACK=$(cat "$ROOT_DIR/.current-stack")
    
    case "$CURRENT_STACK" in
        ollama)
            echo -e "\n${YELLOW}Checking Ollama-specific variables...${NC}"
            check_env_var "OLLAMA_MODELS_PATH"
            check_path "OLLAMA_MODELS_PATH"
            check_env_var "OLLAMA_HOST"
            check_env_var "OLLAMA_KEEP_ALIVE"
            check_env_var "OLLAMA_NUM_PARALLEL"
            check_env_var "OLLAMA_MAX_LOADED_MODELS"
            check_env_var "OLLAMA_MEMORY_LIMIT"
            check_env_var "OLLAMA_MEMORY_RESERVATION"
            check_env_var "DEFAULT_MODEL"
            ;;
        mistral)
            echo -e "\n${YELLOW}Checking Mistral-specific variables...${NC}"
            check_env_var "MISTRAL_MODELS_PATH"
            check_path "MISTRAL_MODELS_PATH"
            check_env_var "MISTRAL_HOST"
            check_env_var "MISTRAL_MODEL_PATH"
            check_env_var "MISTRAL_PORT"
            check_env_var "RUST_LOG"
            check_env_var "MISTRAL_MEMORY_LIMIT"
            check_env_var "MISTRAL_MEMORY_RESERVATION"
            check_env_var "CUDA_VERSION"
            check_env_var "MISTRAL_RS_VERSION"
            check_env_var "DEFAULT_MODEL"
            ;;
    esac
fi

# Check monitoring paths
check_env_var "PROMETHEUS_CONFIG_PATH"
check_env_var "GRAFANA_CONFIG_PATH"

echo ""
echo "Environment validation complete."