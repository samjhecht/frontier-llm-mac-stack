# Frontier LLM Stack

A complete self-hosted LLM infrastructure with coding agent capabilities, designed for Mac Studio but adaptable to other platforms.

## Overview

This project provides everything needed to run a powerful, self-hosted LLM environment with:
- **Ollama** for LLM serving (supporting models like Qwen2.5-Coder)
- **Aider** for AI pair programming
- **Prometheus & Grafana** for monitoring
- **Docker Compose** for easy deployment
- **Nginx** reverse proxy for secure access

## Quick Start

### Option 1: Docker Setup (Recommended)

1. **Prerequisites**
   - Docker Desktop for Mac installed and running
   - At least 32GB RAM (64GB+ recommended)
   - 100GB+ free disk space

2. **Clone and Setup**
   ```bash
   git clone <repository>
   cd frontier-llm-stack
   
   # Run the Docker setup script
   chmod +x scripts/setup/docker-setup.sh
   ./scripts/setup/docker-setup.sh
   ```

3. **Configure Environment**
   ```bash
   # Copy and edit environment file
   cp .env.example .env
   # Edit .env with your preferences
   ```

4. **Start Services**
   ```bash
   ./start.sh
   ```

5. **Pull a Model**
   ```bash
   # Pull the default model (Qwen2.5-Coder 32B)
   ./pull-model.sh
   
   # Or pull a different model
   ./pull-model.sh llama2:13b
   ```

### Option 2: Native Installation

For a native installation without Docker:

```bash
# Install dependencies
./scripts/setup/01-install-dependencies.sh

# Install Ollama
./scripts/setup/02-install-ollama.sh

# Configure Ollama service
./scripts/setup/03-configure-ollama-service.sh
```

## Architecture

```
┌─────────────────┐         ┌──────────────────┐
│  MacBook Pro    │   LAN   │   Mac Studio     │
│                 ├─────────┤                  │
│ - Aider Client  │         │ - Ollama Server  │
│ - Web Browser   │         │ - Monitoring     │
│                 │         │ - Docker Stack   │
└─────────────────┘         └──────────────────┘
```

## Services

### Core Services

- **Ollama** (port 11434): LLM API server
- **Grafana** (port 3000): Metrics visualization
- **Prometheus** (port 9090): Metrics collection
- **Nginx** (port 80/443): Reverse proxy

### Access Points

After starting the stack:
- Ollama API: `http://localhost:11434`
- Grafana Dashboard: `http://localhost:3000` (admin/frontier-llm)
- Prometheus: `http://localhost:9090`

## Using Aider

### With Docker
```bash
# Run Aider in Docker container
docker compose run --rm aider aider /workspace/your-project
```

### Native Installation
```bash
# Install Aider
pip install aider-chat

# Configure for remote Ollama
export OLLAMA_API_BASE="http://mac-studio.local:11434"

# Run Aider
aider --model ollama/qwen2.5-coder:32b-instruct-q8_0
```

## Monitoring

Access Grafana at `http://localhost:3000` to view:
- Model response times
- Memory usage
- GPU utilization (if available)
- Request throughput

## Models

### Recommended Models

1. **Qwen2.5-Coder:32b** - Excellent for coding tasks
   ```bash
   ./pull-model.sh qwen2.5-coder:32b-instruct-q8_0
   ```

2. **Llama 2** - General purpose
   ```bash
   ./pull-model.sh llama2:13b
   ```

3. **CodeLlama** - Specialized for code
   ```bash
   ./pull-model.sh codellama:34b
   ```

## Helper Scripts

- `./start.sh` - Start all services
- `./stop.sh` - Stop all services
- `./pull-model.sh [model]` - Download an Ollama model
- `./logs.sh [service]` - View service logs

## Configuration

### Environment Variables

Edit `.env` file to customize:
- Memory limits
- Model paths
- Port mappings
- Authentication settings

### Adding SSL

1. Place certificates in `config/ssl/`
2. Update `config/nginx/default.conf` for HTTPS
3. Update `.env` with SSL paths

## Troubleshooting

### Ollama not accessible
```bash
# Check if service is running
docker compose ps

# View logs
./logs.sh ollama

# Test API
curl http://localhost:11434/api/version
```

### Memory issues
- Reduce `OLLAMA_MEMORY_LIMIT` in `.env`
- Use smaller model quantizations (q4 instead of q8)

### Slow responses
- Check available memory: `docker stats`
- Reduce concurrent requests: `OLLAMA_NUM_PARALLEL=2`

## Contributing

See [specifications/local-llm-stack-setup.md](specifications/local-llm-stack-setup.md) for detailed implementation plans.

## License

[Your License Here]