#!/bin/bash
set -euo pipefail

# docker-setup.sh - Simplified Docker-based setup for the entire LLM stack
# This script sets up the complete environment using Docker Compose

echo "=== Frontier LLM Stack - Docker Setup ==="

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

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    print_error "This script is designed for macOS only"
    exit 1
fi

# Check Docker installation
print_header "Checking Docker Installation"
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker Desktop for Mac"
    print_status "Visit: https://www.docker.com/products/docker-desktop/"
    exit 1
fi

if ! docker info &> /dev/null; then
    print_error "Docker daemon is not running. Please start Docker Desktop"
    exit 1
fi

print_status "Docker is installed and running"
docker --version
docker compose version

# Check available resources
print_header "System Resources Check"
total_memory=$(sysctl -n hw.memsize | awk '{print $1/1024/1024/1024}')
print_status "Total system memory: ${total_memory}GB"

if (( $(echo "$total_memory < 32" | bc -l) )); then
    print_warning "System has less than 32GB RAM. Large models may not run efficiently"
fi

# Check available disk space
available_space=$(df -g . | awk 'NR==2 {print $4}')
print_status "Available disk space: ${available_space}GB"

if [[ $available_space -lt 100 ]]; then
    print_warning "Less than 100GB available. Large models require significant space"
fi

# Create directory structure
print_header "Creating Directory Structure"
directories=(
    "data/ollama-models"
    "config/ollama"
    "config/prometheus"
    "config/grafana/provisioning/datasources"
    "config/grafana/provisioning/dashboards"
    "config/grafana/dashboards"
    "config/nginx"
    "config/ssl"
    "config/aider"
    "docker/aider"
    "logs"
)

for dir in "${directories[@]}"; do
    mkdir -p "$dir"
    print_status "Created directory: $dir"
done

# Create .env file if it doesn't exist
if [[ ! -f .env ]]; then
    print_status "Creating .env file from template..."
    cp .env.example .env
    print_warning "Please review and update .env file with your preferences"
fi

# Create Prometheus configuration
print_header "Configuring Prometheus"
cat > config/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'ollama'
    static_configs:
      - targets: ['ollama:11434']
    metrics_path: '/api/metrics'
  
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
  
  - job_name: 'nvidia-gpu'
    static_configs:
      - targets: ['nvidia-exporter:9400']
EOF
print_status "Created Prometheus configuration"

# Create Grafana datasource configuration
print_status "Configuring Grafana datasources..."
cat > config/grafana/provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

# Create Grafana dashboard provisioning
cat > config/grafana/provisioning/dashboards/dashboards.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF

# Create basic Ollama dashboard
print_status "Creating Grafana dashboards..."
cat > config/grafana/dashboards/ollama-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "Ollama LLM Monitoring",
    "tags": ["ollama", "llm"],
    "timezone": "browser",
    "panels": [
      {
        "datasource": "Prometheus",
        "fieldConfig": {
          "defaults": {
            "unit": "ms"
          }
        },
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 0,
          "y": 0
        },
        "id": 1,
        "targets": [
          {
            "expr": "rate(ollama_request_duration_seconds[5m]) * 1000",
            "refId": "A"
          }
        ],
        "title": "Response Time",
        "type": "timeseries"
      },
      {
        "datasource": "Prometheus",
        "fieldConfig": {
          "defaults": {
            "unit": "percent"
          }
        },
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 12,
          "y": 0
        },
        "id": 2,
        "targets": [
          {
            "expr": "100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))",
            "refId": "A"
          }
        ],
        "title": "Memory Usage",
        "type": "gauge"
      }
    ],
    "version": 1
  }
}
EOF

# Create Nginx configuration
print_status "Configuring Nginx..."
cat > config/nginx/default.conf << 'EOF'
upstream ollama {
    server ollama:11434;
}

upstream grafana {
    server grafana:3000;
}

server {
    listen 80;
    server_name localhost;

    # Ollama API
    location /api/ {
        proxy_pass http://ollama;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts for long-running requests
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    # Grafana
    location /grafana/ {
        proxy_pass http://grafana/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Create Aider Dockerfile
print_status "Creating Aider Docker configuration..."
cat > docker/aider/Dockerfile << 'EOF'
FROM python:3.12-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Install aider
RUN pip install --no-cache-dir aider-chat

# Create workspace directory
WORKDIR /workspace

# Copy aider configuration
COPY aider.conf.yml /root/.aider.conf.yml

# Set up git config
RUN git config --global user.email "aider@frontier-llm" && \
    git config --global user.name "Aider Assistant"

CMD ["/bin/bash"]
EOF

# Create Aider configuration
cat > docker/aider/aider.conf.yml << 'EOF'
model: ollama/qwen2.5-coder:32b-instruct-q8_0
api-base: http://ollama:11434
edit-format: diff
auto-commits: false
pretty: true
stream: true
map-tokens: 2048
EOF

# Create docker-compose override for Mac-specific settings
print_status "Creating Mac-specific Docker overrides..."
cat > docker-compose.override.yml << 'EOF'
# Mac-specific overrides
version: '3.8'

services:
  ollama:
    # Remove GPU configuration for Mac
    deploy:
      resources:
        limits:
          memory: 64G
        reservations:
          memory: 32G
    # Use host network mode for better performance on Mac
    network_mode: "host"
    ports: []
    environment:
      - OLLAMA_HOST=0.0.0.0:11434

  # Disable NVIDIA exporter on Mac
  nvidia-exporter:
    profiles:
      - never
EOF

# Create helper scripts
print_header "Creating Helper Scripts"

# Start script
cat > start.sh << 'EOF'
#!/bin/bash
echo "Starting Frontier LLM Stack..."
docker compose up -d

echo "Waiting for services to be ready..."
sleep 10

# Check service health
services=("ollama:11434/api/version" "grafana:3000/api/health" "prometheus:9090/-/ready")
for service in "${services[@]}"; do
    IFS=':' read -r name endpoint <<< "$service"
    if curl -s "http://localhost:${endpoint}" > /dev/null; then
        echo "✓ ${name} is ready"
    else
        echo "✗ ${name} is not responding"
    fi
done

echo ""
echo "Access points:"
echo "  Ollama API: http://localhost:11434"
echo "  Grafana: http://localhost:3000 (admin/frontier-llm)"
echo "  Prometheus: http://localhost:9090"
EOF

chmod +x start.sh

# Stop script
cat > stop.sh << 'EOF'
#!/bin/bash
echo "Stopping Frontier LLM Stack..."
docker compose down
EOF

chmod +x stop.sh

# Pull models script
cat > pull-model.sh << 'EOF'
#!/bin/bash
MODEL=${1:-qwen2.5-coder:32b-instruct-q8_0}
echo "Pulling model: $MODEL"
docker compose exec ollama ollama pull $MODEL
EOF

chmod +x pull-model.sh

# Logs script
cat > logs.sh << 'EOF'
#!/bin/bash
SERVICE=${1:-ollama}
docker compose logs -f $SERVICE
EOF

chmod +x logs.sh

print_header "Setup Complete!"
print_status "Docker Compose setup is ready"
print_status ""
print_status "Next steps:"
print_status "1. Review and update .env file"
print_status "2. Run: ./start.sh to start all services"
print_status "3. Run: ./pull-model.sh to download the default model"
print_status "4. Access Grafana at http://localhost:3000"
print_status ""
print_status "Helper scripts:"
print_status "  ./start.sh     - Start all services"
print_status "  ./stop.sh      - Stop all services"
print_status "  ./pull-model.sh [model] - Pull an Ollama model"
print_status "  ./logs.sh [service]     - View service logs"