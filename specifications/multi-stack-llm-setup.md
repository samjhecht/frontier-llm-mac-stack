# Multi-Stack LLM Infrastructure Setup Specification

## Overview

This specification defines the complete automated setup process for a multi-stack LLM infrastructure supporting both Ollama and Mistral.rs inference engines on Mac Studio hardware. The infrastructure provides high-performance local LLM inference with comprehensive monitoring, API compatibility layers, and seamless stack switching.

## Table of Contents

1. [Prerequisites and System Requirements](#prerequisites-and-system-requirements)
2. [Project Structure](#project-structure)
3. [Installation Process](#installation-process)
4. [Stack Configuration](#stack-configuration)
5. [Service Deployment](#service-deployment)
6. [Model Management](#model-management)
7. [Monitoring Setup](#monitoring-setup)
8. [Testing and Validation](#testing-and-validation)
9. [Rollback Procedures](#rollback-procedures)
10. [Configuration Templates](#configuration-templates)

## Prerequisites and System Requirements

### Hardware Requirements

```bash
# Validate hardware specifications
system_profiler SPHardwareDataType | grep -E "Model Name|Chip|Memory"
```

- **Required**: Mac Studio with Apple Silicon (M2/M3 Ultra recommended)
- **Memory**: Minimum 64GB RAM (192GB recommended for large models)
- **Storage**: Minimum 500GB available space for models and data
- **Network**: Stable internet connection for model downloads

### Software Dependencies

```bash
# Check Docker installation
docker --version || echo "Docker not installed"
docker-compose --version || echo "Docker Compose not installed"

# Check Git installation
git --version || echo "Git not installed"

# Check required tools
command -v curl || echo "curl not installed"
command -v jq || echo "jq not installed"
```

Required software:
- Docker Desktop for Mac (latest version)
- Docker Compose v2.0+ 
- Git 2.30+
- curl
- jq (for JSON processing)
- bash 4.0+

### System Configuration

```bash
# Verify Docker daemon is running
docker info > /dev/null 2>&1 || { echo "Docker daemon not running"; exit 1; }

# Check Docker resources
docker system info | grep -E "CPUs|Total Memory"

# Ensure sufficient Docker resources (Docker Desktop settings)
# Memory: At least 32GB allocated
# CPUs: At least 8 cores allocated
# Disk image size: At least 200GB
```

## Project Structure

### Create Directory Structure

```bash
# Create project root
PROJECT_ROOT="$HOME/frontier-llm-stack"
mkdir -p "$PROJECT_ROOT"
cd "$PROJECT_ROOT"

# Initialize Git repository
git init
# Add your repository remote if needed:
# git remote add origin https://github.com/yourusername/yourrepo.git

# Create stack directories
mkdir -p stacks/{common,ollama,mistral}
mkdir -p stacks/common/{base,monitoring,nginx}
mkdir -p stacks/mistral/{api-proxy,config,docker,tests}
mkdir -p stacks/ollama/config
mkdir -p data/{models,prometheus,grafana}
mkdir -p logs/{ollama,mistral,monitoring}
mkdir -p scripts
mkdir -p specifications
mkdir -p docs/stacks/{ollama,mistral}

# Set permissions
chmod 755 scripts
chmod 755 stacks/*/
```

### File Structure Validation

```bash
# Validate structure
tree -L 3 . || find . -type d -maxdepth 3 | sort
```

Expected structure:
```
.
├── data/
│   ├── grafana/
│   ├── models/
│   └── prometheus/
├── docs/
│   └── stacks/
│       ├── mistral/
│       └── ollama/
├── logs/
│   ├── mistral/
│   ├── monitoring/
│   └── ollama/
├── scripts/
├── specifications/
└── stacks/
    ├── common/
    │   ├── base/
    │   ├── monitoring/
    │   └── nginx/
    ├── mistral/
    │   ├── api-proxy/
    │   ├── config/
    │   ├── docker/
    │   └── tests/
    └── ollama/
        └── config/
```

## Installation Process

### Phase 1: Core Setup

```bash
# 1. Clone repository or create from scratch
if [ ! -d ".git" ]; then
    git init
    echo "# Frontier LLM Stack" > README.md
    git add README.md
    git commit -m "Initial commit"
fi

# 2. Create environment configuration
cat > .env.example << 'EOF'
# Frontier LLM Stack Environment Configuration
# Copy this file to .env and adjust values as needed

# Stack Selection
CURRENT_STACK=ollama

# Ollama Configuration
OLLAMA_MODELS_PATH=./data/models/ollama
OLLAMA_HOST=0.0.0.0:11434
OLLAMA_KEEP_ALIVE=10m
OLLAMA_NUM_PARALLEL=4
OLLAMA_MAX_LOADED_MODELS=2

# Mistral Configuration
MISTRAL_API_PORT=8080
MISTRAL_MODELS_PATH=./data/models/mistral
MISTRAL_MEMORY_LIMIT=64G
MISTRAL_MEMORY_RESERVATION=32G
MISTRAL_LOG_LEVEL=info
MISTRAL_MAX_BATCH_SIZE=8
MISTRAL_MODEL_TYPE=plain
ENABLE_METAL=true
ENABLE_CUDA=false

# Default Model
DEFAULT_MODEL=qwen2.5-coder:32b-instruct-q8_0

# Grafana Configuration
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=frontier-llm

# Resource Limits (adjust based on your Mac Studio specs)
MEMORY_LIMIT=64G
MEMORY_RESERVATION=32G

# Network Configuration
NGINX_HTTP_PORT=80
NGINX_HTTPS_PORT=443
API_PORT=11434
GRAFANA_PORT=3000
PROMETHEUS_PORT=9090

# SSL Configuration (for production)
SSL_CERT_PATH=./config/ssl/cert.pem
SSL_KEY_PATH=./config/ssl/key.pem

# Development Mode
ENABLE_AIDER=true
ENABLE_GPU_MONITORING=false
EOF

# Copy to active configuration
cp .env.example .env

# 3. Create stack selection script
cat > stack-select.sh << 'EOF'
#!/bin/bash

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STACKS_DIR="${SCRIPT_DIR}/stacks"
CURRENT_STACK_FILE="${SCRIPT_DIR}/.current-stack"

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

list_stacks() {
    print_info "Available stacks:"
    for stack in "${STACKS_DIR}"/*; do
        if [[ -d "$stack" && "$stack" != */common ]]; then
            stack_name=$(basename "$stack")
            if [[ -f "$CURRENT_STACK_FILE" ]] && [[ "$(cat "$CURRENT_STACK_FILE")" == "$stack_name" ]]; then
                echo -e "  - ${GREEN}${stack_name}${NC} (current)"
            else
                echo "  - $stack_name"
            fi
        fi
    done
}

get_current_stack() {
    if [[ -f "$CURRENT_STACK_FILE" ]]; then
        cat "$CURRENT_STACK_FILE"
    else
        echo ""
    fi
}

select_stack() {
    local stack_name=$1
    local stack_dir="${STACKS_DIR}/${stack_name}"
    
    if [[ ! -d "$stack_dir" ]]; then
        print_error "Stack '${stack_name}' does not exist"
        list_stacks
        exit 1
    fi
    
    if [[ ! -f "${stack_dir}/docker-compose.yml" ]]; then
        print_error "Stack '${stack_name}' is missing docker-compose.yml"
        exit 1
    fi
    
    print_info "Selecting stack: ${stack_name}"
    echo "$stack_name" > "$CURRENT_STACK_FILE"
    
    cat > "${SCRIPT_DIR}/docker-compose.yml" << 'COMPOSE_EOF'
version: '3.8'

# Auto-generated docker-compose.yml - DO NOT EDIT
# Generated by stack-select.sh
# 
# This file is a stub. The actual configuration is managed by:
# - ./stack-select.sh (to select the active stack)
# - ./docker-compose-wrapper.sh (to run docker-compose with the correct files)
# - ./start.sh and ./stop.sh (convenience scripts)
#
# The wrapper script automatically includes:
# - stacks/common/base/docker-compose.yml
# - stacks/<selected-stack>/docker-compose.yml
# - stacks/common/monitoring/docker-compose.yml  
# - stacks/common/nginx/docker-compose.yml
#
# To manage services, use:
# ./start.sh              # Start all services
# ./stop.sh               # Stop all services
# ./docker-compose-wrapper.sh ps   # Check status
# ./docker-compose-wrapper.sh logs  # View logs
#
COMPOSE_EOF
    
    print_success "Stack '${stack_name}' selected"
}

case "${1:-}" in
    list)
        list_stacks
        ;;
    current)
        current=$(get_current_stack)
        if [[ -n "$current" ]]; then
            echo "Current stack: $current"
        else
            echo "No stack selected"
        fi
        ;;
    select)
        if [[ -z "${2:-}" ]]; then
            print_error "Usage: $0 select <stack-name>"
            exit 1
        fi
        select_stack "$2"
        ;;
    *)
        echo "Usage: $0 {list|current|select <stack-name>}"
        exit 1
        ;;
esac
EOF

chmod +x stack-select.sh

# 4. Create Docker Compose wrapper
cat > docker-compose-wrapper.sh << 'EOF'
#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CURRENT_STACK_FILE="${SCRIPT_DIR}/.current-stack"

if [ ! -f "$CURRENT_STACK_FILE" ]; then
    echo "Error: No stack selected. Run './stack-select.sh select <stack>' first."
    exit 1
fi

CURRENT_STACK=$(cat "$CURRENT_STACK_FILE")

# Build the docker-compose command with the correct file order
COMPOSE_FILES=""
COMPOSE_FILES="$COMPOSE_FILES -f ${SCRIPT_DIR}/stacks/common/base/docker-compose.yml"
COMPOSE_FILES="$COMPOSE_FILES -f ${SCRIPT_DIR}/stacks/${CURRENT_STACK}/docker-compose.yml"

# Add CUDA override for Mistral if on Linux with NVIDIA
if [ "$CURRENT_STACK" = "mistral" ] && [ -f "${SCRIPT_DIR}/stacks/mistral/docker-compose.cuda.yml" ]; then
    if command -v nvidia-smi &> /dev/null; then
        COMPOSE_FILES="$COMPOSE_FILES -f ${SCRIPT_DIR}/stacks/mistral/docker-compose.cuda.yml"
    fi
fi

COMPOSE_FILES="$COMPOSE_FILES -f ${SCRIPT_DIR}/stacks/common/monitoring/docker-compose.yml"
COMPOSE_FILES="$COMPOSE_FILES -f ${SCRIPT_DIR}/stacks/common/nginx/docker-compose.yml"

# Execute docker-compose with the merged configuration
exec docker-compose $COMPOSE_FILES "$@"
EOF

chmod +x docker-compose-wrapper.sh
```

### Phase 2: Stack Components Setup

```bash
# 1. Create Common Base Configuration
cat > stacks/common/base/docker-compose.yml << 'EOF'
version: '3.8'

networks:
  frontier-llm-network:
    driver: bridge
    name: frontier-llm-network
  frontier-monitoring:
    driver: bridge
    name: frontier-monitoring

volumes:
  prometheus-data:
    driver: local
  grafana-data:
    driver: local
EOF

# 2. Create Monitoring Configuration
cat > stacks/common/monitoring/docker-compose.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: frontier-prometheus
    volumes:
      - ./stacks/common/monitoring/config/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    ports:
      - "${PROMETHEUS_PORT:-9090}:9090"
    networks:
      - frontier-monitoring
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:9090/-/healthy"]
      interval: 30s
      timeout: 10s
      retries: 3

  grafana:
    image: grafana/grafana:latest
    container_name: frontier-grafana
    environment:
      - GF_SECURITY_ADMIN_USER=${GRAFANA_ADMIN_USER:-admin}
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-frontier-llm}
      - GF_INSTALL_PLUGINS=
    volumes:
      - grafana-data:/var/lib/grafana
      - ./stacks/common/monitoring/config/grafana/provisioning:/etc/grafana/provisioning:ro
    ports:
      - "${GRAFANA_PORT:-3000}:3000"
    networks:
      - frontier-monitoring
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:3000/api/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF

# 3. Create Prometheus configuration
mkdir -p stacks/common/monitoring/config
cat > stacks/common/monitoring/config/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'ollama'
    static_configs:
      - targets: ['ollama:11434']
    metrics_path: /api/metrics

  - job_name: 'mistral'
    static_configs:
      - targets: ['mistral:8080']
    metrics_path: /metrics

  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
EOF
```

### Phase 3: Ollama Stack Setup

```bash
# Create Ollama Docker Compose configuration
cat > stacks/ollama/docker-compose.yml << 'EOF'
version: '3.8'

services:
  ollama:
    image: ollama/ollama:latest
    container_name: frontier-ollama
    volumes:
      - ${OLLAMA_MODELS_PATH:-./data/models/ollama}:/root/.ollama
    environment:
      - OLLAMA_HOST=${OLLAMA_HOST:-0.0.0.0:11434}
      - OLLAMA_KEEP_ALIVE=${OLLAMA_KEEP_ALIVE:-10m}
      - OLLAMA_NUM_PARALLEL=${OLLAMA_NUM_PARALLEL:-4}
      - OLLAMA_MAX_LOADED_MODELS=${OLLAMA_MAX_LOADED_MODELS:-2}
    ports:
      - "${API_PORT:-11434}:11434"
    networks:
      - frontier-llm-network
      - frontier-monitoring
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: ${MEMORY_LIMIT:-64G}
        reservations:
          memory: ${MEMORY_RESERVATION:-32G}
    healthcheck:
      test: ["CMD", "ollama", "list"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
EOF
```

### Phase 4: Mistral.rs Stack Setup

```bash
# 1. Create Mistral Docker Compose configuration
cat > stacks/mistral/docker-compose.yml << 'EOF'
version: '3.8'

services:
  mistral:
    image: frontier-mistral:latest
    build:
      context: ./stacks/mistral
      dockerfile: docker/Dockerfile
      args:
        ENABLE_METAL: ${ENABLE_METAL:-true}
        ENABLE_CUDA: ${ENABLE_CUDA:-false}
    container_name: frontier-mistral
    volumes:
      - ${MISTRAL_MODELS_PATH:-./data/models/mistral}:/models:ro
      - ./stacks/mistral/config:/config:ro
    environment:
      - MISTRAL_MODEL_PATH=/models
      - MISTRAL_CONFIG_PATH=/config
      - MISTRAL_LOG_LEVEL=${MISTRAL_LOG_LEVEL:-info}
      - MISTRAL_MAX_BATCH_SIZE=${MISTRAL_MAX_BATCH_SIZE:-8}
      - MISTRAL_MODEL_TYPE=${MISTRAL_MODEL_TYPE:-plain}
      - MISTRAL_MODEL_ID=${MISTRAL_MODEL_ID:-}
      - RUST_LOG=${MISTRAL_LOG_LEVEL:-info}
    ports:
      - "${MISTRAL_API_PORT:-8080}:8080"
    networks:
      - frontier-llm-network
      - frontier-monitoring
    restart: unless-stopped
    # Note: deploy.resources is only supported in Docker Swarm mode
    # For standard docker-compose, resource limits should be set in Docker Desktop
    # or via docker run flags. Uncomment below if using Docker Swarm:
    # deploy:
    #   resources:
    #     limits:
    #       memory: ${MISTRAL_MEMORY_LIMIT:-64G}
    #     reservations:
    #       memory: ${MISTRAL_MEMORY_RESERVATION:-32G}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 120s

  mistral-api-proxy:
    image: frontier-mistral-api-proxy:latest
    build:
      context: ./stacks/mistral/api-proxy
      dockerfile: Dockerfile
    container_name: frontier-mistral-api-proxy
    environment:
      - MISTRAL_BACKEND_URL=http://mistral:8080
      - PROXY_PORT=11434
      - LOG_LEVEL=${MISTRAL_LOG_LEVEL:-info}
    ports:
      - "${API_PORT:-11434}:11434"
    networks:
      - frontier-llm-network
    depends_on:
      - mistral
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:11434/api/tags"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF

# 2. Create Mistral Dockerfile
mkdir -p stacks/mistral/docker
cat > stacks/mistral/docker/Dockerfile << 'EOF'
FROM rust:1.75 as builder

ARG ENABLE_METAL=false
ARG ENABLE_CUDA=false

WORKDIR /build

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    cmake \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone and build mistral.rs
RUN git clone https://github.com/EricLBuehler/mistral.rs.git
WORKDIR /build/mistral.rs

# Build with appropriate features
RUN if [ "$ENABLE_CUDA" = "true" ]; then \
        cargo build --release --features cuda; \
    elif [ "$ENABLE_METAL" = "true" ]; then \
        cargo build --release --features metal; \
    else \
        cargo build --release; \
    fi

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/mistral.rs/target/release/mistralrs-server /usr/local/bin/

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["mistralrs-server"]
CMD ["--port", "8080"]
EOF

# 3. Create build script for Mistral
cat > stacks/mistral/build.sh << 'EOF'
#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Building Mistral.rs Docker image..."

# Detect platform for Metal support
if [[ "$OSTYPE" == "darwin"* ]]; then
    ENABLE_METAL=true
    ENABLE_CUDA=false
    echo "Detected macOS - enabling Metal acceleration"
else
    ENABLE_METAL=false
    # Check for NVIDIA GPU
    if command -v nvidia-smi &> /dev/null; then
        ENABLE_CUDA=true
        echo "Detected NVIDIA GPU - enabling CUDA acceleration"
    else
        ENABLE_CUDA=false
        echo "No GPU detected - using CPU mode"
    fi
fi

docker build \
    --build-arg ENABLE_METAL=$ENABLE_METAL \
    --build-arg ENABLE_CUDA=$ENABLE_CUDA \
    -t frontier-mistral:latest \
    -f "$SCRIPT_DIR/docker/Dockerfile" \
    "$SCRIPT_DIR"

echo "Building API proxy..."
docker build \
    -t frontier-mistral-api-proxy:latest \
    -f "$SCRIPT_DIR/api-proxy/Dockerfile" \
    "$SCRIPT_DIR/api-proxy"

echo "Build complete!"
EOF

chmod +x stacks/mistral/build.sh
```

## Service Deployment

### Start Services Script

```bash
# Create start script
cat > start.sh << 'EOF'
#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_error() { echo -e "${RED}ERROR: $1${NC}" >&2; }
print_success() { echo -e "${GREEN}SUCCESS: $1${NC}"; }
print_info() { echo -e "${YELLOW}INFO: $1${NC}"; }
print_warning() { echo -e "${YELLOW}WARNING: $1${NC}"; }

# Check Docker
if ! docker info >/dev/null 2>&1; then
    print_error "Docker daemon is not running"
    exit 1
fi

# Check stack selection
if [ ! -f ".current-stack" ]; then
    print_error "No stack selected. Run './stack-select.sh select <stack>' first."
    exit 1
fi

CURRENT_STACK=$(cat .current-stack)
print_info "Starting Frontier LLM Stack with ${CURRENT_STACK} stack..."

# For Mistral, build if needed
if [ "${CURRENT_STACK}" = "mistral" ]; then
    if ! docker image inspect frontier-mistral:latest >/dev/null 2>&1; then
        print_info "Building Mistral Docker image..."
        ./stacks/mistral/build.sh || exit 1
    fi
fi

# Create network if not exists
docker network create frontier-llm-network 2>/dev/null || true
docker network create frontier-monitoring 2>/dev/null || true

# Start services
print_info "Starting services..."
./docker-compose-wrapper.sh up -d || exit 1

# Wait for health
print_info "Waiting for services to be healthy..."
sleep 5

# Check health
./docker-compose-wrapper.sh ps

print_success "Stack started successfully!"
print_info "Access points:"
echo "  - ${CURRENT_STACK^} API: http://localhost:11434"
echo "  - Grafana: http://localhost:3000"
echo "  - Prometheus: http://localhost:9090"
EOF

chmod +x start.sh

# Create stop script
cat > stop.sh << 'EOF'
#!/bin/bash

set -e

echo "Stopping Frontier LLM Stack..."
./docker-compose-wrapper.sh down
echo "Stack stopped."
EOF

chmod +x stop.sh
```

## Model Management

### Model Download Scripts

```bash
# Create Ollama model management script
cat > scripts/ollama-models.sh << 'EOF'
#!/bin/bash

set -e

case "${1:-}" in
    pull)
        docker exec frontier-ollama ollama pull "${2:-qwen2.5-coder:32b-instruct-q8_0}"
        ;;
    list)
        docker exec frontier-ollama ollama list
        ;;
    rm)
        docker exec frontier-ollama ollama rm "$2"
        ;;
    *)
        echo "Usage: $0 {pull <model>|list|rm <model>}"
        exit 1
        ;;
esac
EOF

chmod +x scripts/ollama-models.sh

# Create Mistral model download script
cat > stacks/mistral/download-model.sh << 'EOF'
#!/bin/bash

set -e

MODELS_DIR="${MISTRAL_MODELS_PATH:-./data/models/mistral}"

case "${1:-}" in
    list-available)
        echo "Available Mistral models:"
        echo "  - mistralai/Mistral-7B-v0.1"
        echo "  - mistralai/Mistral-7B-Instruct-v0.1"
        echo "  - mistralai/Mixtral-8x7B-v0.1"
        echo "  - mistralai/Mixtral-8x7B-Instruct-v0.1"
        ;;
    download)
        MODEL_URL="$2"
        if [ -z "$MODEL_URL" ]; then
            echo "Usage: $0 download <model-url>"
            exit 1
        fi
        mkdir -p "$MODELS_DIR"
        echo "Downloading model to $MODELS_DIR..."
        cd "$MODELS_DIR"
        # Use git-lfs for Hugging Face models
        git lfs install
        git clone "$MODEL_URL"
        echo "Download complete!"
        ;;
    check)
        echo "Downloaded models in $MODELS_DIR:"
        ls -la "$MODELS_DIR" 2>/dev/null || echo "No models found"
        ;;
    *)
        echo "Usage: $0 {list-available|download <url>|check}"
        exit 1
        ;;
esac
EOF

chmod +x stacks/mistral/download-model.sh
```

## Testing and Validation

### Validation Checkpoints

```bash
# Create comprehensive validation script
cat > scripts/validate-setup.sh << 'EOF'
#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

check() {
    local name="$1"
    local command="$2"
    printf "Checking %-40s" "$name..."
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        ((ERRORS++))
        return 1
    fi
}

warn_check() {
    local name="$1"
    local command="$2"
    printf "Checking %-40s" "$name..."
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠${NC}"
        ((WARNINGS++))
        return 1
    fi
}

echo "=== Frontier LLM Stack Validation ==="
echo

echo "1. System Requirements"
check "Docker installed" "docker --version"
check "Docker daemon running" "docker info"
check "Docker Compose installed" "docker-compose --version"
check "Git installed" "git --version"

echo
echo "2. Project Structure"
check "Stack directory exists" "[ -d stacks ]"
check "Common stack exists" "[ -d stacks/common ]"
check "Ollama stack exists" "[ -d stacks/ollama ]"
check "Mistral stack exists" "[ -d stacks/mistral ]"
check "Data directory exists" "[ -d data ]"

echo
echo "3. Configuration"
check "Environment file exists" "[ -f .env ]"
check "Stack selection script exists" "[ -x stack-select.sh ]"
check "Docker wrapper exists" "[ -x docker-compose-wrapper.sh ]"
check "Start script exists" "[ -x start.sh ]"
check "Stop script exists" "[ -x stop.sh ]"

echo
echo "4. Stack Selection"
check "Current stack file exists" "[ -f .current-stack ]"
if [ -f .current-stack ]; then
    CURRENT_STACK=$(cat .current-stack)
    echo "   Current stack: $CURRENT_STACK"
fi

echo
echo "5. Network Configuration"
warn_check "Docker network exists" "docker network inspect frontier-llm-network"
warn_check "Monitoring network exists" "docker network inspect frontier-monitoring"

echo
echo "6. Service Health (if running)"
if [ -f .current-stack ]; then
    CURRENT_STACK=$(cat .current-stack)
    warn_check "${CURRENT_STACK^} service running" "./docker-compose-wrapper.sh ps | grep -q $CURRENT_STACK"
    warn_check "Prometheus running" "./docker-compose-wrapper.sh ps | grep -q prometheus"
    warn_check "Grafana running" "./docker-compose-wrapper.sh ps | grep -q grafana"
fi

echo
echo "7. API Endpoints (if running)"
warn_check "LLM API responding" "curl -s http://localhost:11434/api/tags"
warn_check "Grafana responding" "curl -s http://localhost:3000/api/health"
warn_check "Prometheus responding" "curl -s http://localhost:9090/-/healthy"

echo
echo "=== Validation Summary ==="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}Validation passed with $WARNINGS warnings${NC}"
    exit 0
else
    echo -e "${RED}Validation failed with $ERRORS errors and $WARNINGS warnings${NC}"
    exit 1
fi
EOF

chmod +x scripts/validate-setup.sh
```

### Integration Tests

```bash
# Create integration test script
cat > scripts/test-integration.sh << 'EOF'
#!/bin/bash

set -e

echo "=== Integration Tests ==="

# Test 1: API availability
echo -n "Testing API availability... "
if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo "✓"
else
    echo "✗"
    exit 1
fi

# Test 2: Model listing
echo -n "Testing model listing... "
if [ "$(cat .current-stack)" = "ollama" ]; then
    docker exec frontier-ollama ollama list >/dev/null 2>&1 && echo "✓" || echo "✗"
else
    curl -s http://localhost:8080/v1/models >/dev/null 2>&1 && echo "✓" || echo "✗"
fi

# Test 3: Monitoring
echo -n "Testing Prometheus... "
curl -s http://localhost:9090/-/healthy | grep -q "Prometheus Server is Healthy" && echo "✓" || echo "✗"

echo -n "Testing Grafana... "
curl -s http://localhost:3000/api/health | grep -q "ok" && echo "✓" || echo "✗"

# Test 4: Chat completion (if model available)
echo -n "Testing chat completion... "
if [ "$(cat .current-stack)" = "ollama" ]; then
    curl -s -X POST http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d '{"model":"test","prompt":"Hello"}' >/dev/null 2>&1 && echo "✓" || echo "⚠ (no model)"
else
    curl -s -X POST http://localhost:8080/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d '{"model":"test","messages":[{"role":"user","content":"Hello"}]}' >/dev/null 2>&1 && echo "✓" || echo "⚠ (no model)"
fi

echo "Integration tests complete!"
EOF

chmod +x scripts/test-integration.sh
```

## Rollback Procedures

### Rollback Script

```bash
# Create rollback script
cat > scripts/rollback.sh << 'EOF'
#!/bin/bash

set -e

echo "=== Frontier LLM Stack Rollback ==="

# Backup current state
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "1. Backing up current configuration..."
cp -r .env .current-stack docker-compose.yml "$BACKUP_DIR/" 2>/dev/null || true

echo "2. Stopping all services..."
./docker-compose-wrapper.sh down 2>/dev/null || true

echo "3. Removing Docker resources..."
docker network rm frontier-llm-network 2>/dev/null || true
docker network rm frontier-monitoring 2>/dev/null || true

echo "4. Cleaning up Docker images (optional)..."
read -p "Remove custom Docker images? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker rmi frontier-mistral:latest 2>/dev/null || true
    docker rmi frontier-mistral-api-proxy:latest 2>/dev/null || true
fi

echo "5. Resetting configuration..."
rm -f .current-stack
rm -f docker-compose.yml

echo "Rollback complete. To restore:"
echo "  1. Run './stack-select.sh select <stack>'"
echo "  2. Review and update .env configuration"
echo "  3. Run './start.sh'"
EOF

chmod +x scripts/rollback.sh
```

## Configuration Templates

### Environment Configuration Template

```bash
# Full environment template with all options
cat > .env.template << 'EOF'
# ================================================
# Frontier LLM Stack - Complete Configuration
# ================================================

# === Stack Selection ===
CURRENT_STACK=ollama  # Options: ollama, mistral

# === Ollama Configuration ===
OLLAMA_MODELS_PATH=./data/models/ollama
OLLAMA_HOST=0.0.0.0:11434
OLLAMA_KEEP_ALIVE=10m
OLLAMA_NUM_PARALLEL=4
OLLAMA_MAX_LOADED_MODELS=2
OLLAMA_ORIGINS=*  # CORS origins

# === Mistral Configuration ===
MISTRAL_API_PORT=8080
MISTRAL_MODELS_PATH=./data/models/mistral
MISTRAL_MEMORY_LIMIT=64G
MISTRAL_MEMORY_RESERVATION=32G
MISTRAL_LOG_LEVEL=info
MISTRAL_MAX_BATCH_SIZE=8
MISTRAL_MODEL_TYPE=plain  # Options: plain, gguf, lora, x-lora
MISTRAL_MODEL_ID=mistralai/Mistral-7B-Instruct-v0.1
MISTRAL_MODEL_REVISION=main
MISTRAL_TOKENIZER_JSON=/models/tokenizer.json
MISTRAL_QUANTIZATION=q8_0  # Options: none, q4_0, q4_1, q5_0, q5_1, q8_0
ENABLE_METAL=true  # macOS Metal acceleration
ENABLE_CUDA=false  # NVIDIA CUDA acceleration
MISTRAL_DEVICE=cpu  # Options: cpu, cuda, metal

# === Model Configuration ===
DEFAULT_MODEL=qwen2.5-coder:32b-instruct-q8_0
MODEL_TIMEOUT=600  # seconds
MAX_CONTEXT_LENGTH=32768
DEFAULT_TEMPERATURE=0.7
DEFAULT_TOP_P=0.9
DEFAULT_TOP_K=40

# === Resource Limits ===
MEMORY_LIMIT=64G
MEMORY_RESERVATION=32G
CPU_LIMIT=16
CPU_RESERVATION=8

# === Monitoring Configuration ===
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=frontier-llm
PROMETHEUS_RETENTION=30d
PROMETHEUS_SCRAPE_INTERVAL=15s

# === Network Configuration ===
API_PORT=11434
GRAFANA_PORT=3000
PROMETHEUS_PORT=9090
NGINX_HTTP_PORT=80
NGINX_HTTPS_PORT=443

# === SSL Configuration ===
ENABLE_SSL=false
SSL_CERT_PATH=./config/ssl/cert.pem
SSL_KEY_PATH=./config/ssl/key.pem
SSL_DHPARAM_PATH=./config/ssl/dhparam.pem

# === Development Settings ===
ENABLE_AIDER=true
ENABLE_DEBUG=false
ENABLE_GPU_MONITORING=false
LOG_LEVEL=info  # Options: debug, info, warn, error

# === Performance Tuning ===
ENABLE_FLASH_ATTENTION=true
ENABLE_CACHE=true
CACHE_SIZE=10GB
NUM_WORKERS=4
BATCH_TIMEOUT=100ms

# === Security ===
API_KEY=  # Optional API key for authentication
ENABLE_AUTH=false
AUTH_PROVIDER=local  # Options: local, oauth, ldap
ALLOWED_ORIGINS=http://localhost:*
RATE_LIMIT=100  # requests per minute

# === Backup Configuration ===
BACKUP_ENABLED=false
BACKUP_SCHEDULE="0 2 * * *"  # Daily at 2 AM
BACKUP_RETENTION_DAYS=7
BACKUP_PATH=./backups
EOF
```

### Grafana Dashboard Template

```bash
# Create Grafana provisioning
mkdir -p stacks/common/monitoring/config/grafana/provisioning/{dashboards,datasources}

# Datasource configuration
cat > stacks/common/monitoring/config/grafana/provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

# Dashboard configuration
cat > stacks/common/monitoring/config/grafana/provisioning/dashboards/dashboard.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    options:
      path: /etc/grafana/provisioning/dashboards
EOF
```

## Automated Setup Script

### Complete Setup Automation

```bash
# Create master setup script
cat > setup.sh << 'EOF'
#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Frontier LLM Stack Setup${NC}"
echo -e "${BLUE}================================${NC}"
echo

# Function to prompt for selection
select_stack() {
    echo "Select your inference engine:"
    echo "1) Ollama (recommended for ease of use)"
    echo "2) Mistral.rs (recommended for performance)"
    read -p "Enter choice [1-2]: " choice
    
    case $choice in
        1) echo "ollama" ;;
        2) echo "mistral" ;;
        *) echo "ollama" ;;
    esac
}

# Step 1: Check prerequisites
echo -e "${YELLOW}Step 1: Checking prerequisites...${NC}"
./scripts/validate-setup.sh || {
    echo -e "${RED}Prerequisites check failed. Please install missing components.${NC}"
    exit 1
}

# Step 2: Configure environment
echo -e "${YELLOW}Step 2: Configuring environment...${NC}"
if [ ! -f .env ]; then
    cp .env.example .env
    echo "Created .env file. Please review and adjust settings."
fi

# Step 3: Select stack
echo -e "${YELLOW}Step 3: Selecting stack...${NC}"
STACK=$(select_stack)
./stack-select.sh select "$STACK"
echo "Selected $STACK stack"

# Step 4: Build images (for Mistral)
if [ "$STACK" = "mistral" ]; then
    echo -e "${YELLOW}Step 4: Building Mistral images...${NC}"
    ./stacks/mistral/build.sh
fi

# Step 5: Start services
echo -e "${YELLOW}Step 5: Starting services...${NC}"
./start.sh

# Step 6: Validate deployment
echo -e "${YELLOW}Step 6: Validating deployment...${NC}"
sleep 10
./scripts/test-integration.sh

echo
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo
echo "Access points:"
echo "  - LLM API: http://localhost:11434"
echo "  - Grafana: http://localhost:3000 (admin/frontier-llm)"
echo "  - Prometheus: http://localhost:9090"
echo
echo "Next steps:"
echo "  1. Download a model:"
if [ "$STACK" = "ollama" ]; then
    echo "     ./scripts/ollama-models.sh pull qwen2.5-coder:32b"
else
    echo "     ./stacks/mistral/download-model.sh list-available"
    echo "     ./stacks/mistral/download-model.sh download <model-url>"
fi
echo "  2. Test the API:"
echo "     curl http://localhost:11434/api/tags"
echo "  3. Configure Aider:"
echo "     export OLLAMA_API_BASE=http://localhost:11434"
echo "     aider --model ollama/<your-model>"
EOF

chmod +x setup.sh
```

## Validation Matrix

| Component | Check | Command | Expected Result |
|-----------|-------|---------|-----------------|
| Docker | Installation | `docker --version` | Version 20.10+ |
| Docker | Daemon | `docker info` | No errors |
| Docker Compose | Installation | `docker-compose --version` | Version 2.0+ |
| Project | Structure | `[ -d stacks ]` | Directory exists |
| Config | Environment | `[ -f .env ]` | File exists |
| Stack | Selection | `[ -f .current-stack ]` | File exists |
| Network | Docker networks | `docker network ls` | Networks created |
| Services | Ollama/Mistral | `docker ps` | Container running |
| Services | Monitoring | `docker ps` | Prometheus/Grafana running |
| API | LLM endpoint | `curl localhost:11434/api/tags` | JSON response |
| API | Grafana | `curl localhost:3000/api/health` | OK status |
| API | Prometheus | `curl localhost:9090/-/healthy` | Healthy status |
| Models | Availability | Stack-specific commands | Model listed |

## Troubleshooting Guide

### Common Issues and Solutions

1. **Docker daemon not running**
   ```bash
   # macOS
   open -a Docker
   # Wait for Docker to start
   sleep 30
   ```

2. **Port already in use**
   ```bash
   # Find process using port
   lsof -i :11434
   # Update port in .env file
   API_PORT=11435
   ```

3. **Insufficient memory**
   ```bash
   # Check Docker memory allocation
   docker system info | grep Memory
   # Increase in Docker Desktop settings
   ```

4. **Model download fails**
   ```bash
   # Check disk space
   df -h
   # Clean Docker resources
   docker system prune -a
   ```

5. **Service unhealthy**
   ```bash
   # Check logs
   ./docker-compose-wrapper.sh logs <service>
   # Restart service
   ./docker-compose-wrapper.sh restart <service>
   ```

## Success Criteria Checklist

- [ ] All prerequisites installed and validated
- [ ] Project structure created correctly
- [ ] Stack selection mechanism working
- [ ] Environment configuration complete
- [ ] Docker images built successfully (Mistral)
- [ ] All services starting without errors
- [ ] Health checks passing for all services
- [ ] API endpoints responding correctly
- [ ] Monitoring dashboards accessible
- [ ] Model download and loading successful
- [ ] Integration tests passing
- [ ] Aider successfully connects to API
- [ ] Performance meets expectations
- [ ] Rollback procedure tested and working

## Conclusion

This specification provides a complete, automated setup process for the Frontier LLM Stack supporting both Ollama and Mistral.rs inference engines. The setup can be executed unattended using the provided scripts, with comprehensive validation and rollback procedures ensuring a reliable deployment.

Total estimated setup time: 15-30 minutes (excluding model downloads)