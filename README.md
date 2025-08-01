# Frontier LLM Stack

A complete self-hosted LLM infrastructure with coding agent capabilities, designed for Mac Studio but adaptable to other platforms.

## Overview

This project provides everything needed to run a powerful, self-hosted LLM environment with support for multiple inference engines:

### Available Stacks
- **Ollama Stack** (Production Ready) - Mature Go-based LLM serving
- **Mistral Stack** (Coming Soon) - High-performance Rust-based inference

### Common Features
- **Prometheus & Grafana** for comprehensive monitoring
- **Docker Compose** for easy deployment
- **Nginx** reverse proxy for secure access
- **Flexible stack selection** for choosing inference engines

## Prerequisites

### Hardware Requirements
- Mac Studio with M2/M3 Ultra (recommended)
- Minimum 64GB RAM (192GB recommended for Qwen3-235B)
- 500GB+ free storage (1TB+ for Qwen3-235B)
- MacBook Pro for remote development

### Software Requirements
- macOS Ventura or later
- Docker Desktop for Mac
- Git
- SSH access between machines

## Setup Instructions

### Step 1: Enable SSH Access on Mac Studio

Before running any automated setup, you must manually enable SSH access on your Mac Studio. 

**See [docs/ssh-setup-guide.md](docs/ssh-setup-guide.md) for detailed instructions.**

Quick steps:
1. On Mac Studio: System Settings → General → Sharing → Enable Remote Login
2. Test from MacBook Pro: `ssh username@mac-studio.local`
3. Set up SSH keys for passwordless access (recommended)

### Step 2: Clone Repository on Both Machines

1. **On your MacBook Pro:**
   ```bash
   git clone https://github.com/yourusername/frontier-llm-mac-stack.git
   cd frontier-llm-mac-stack
   ```

2. **On Mac Studio (via SSH):**
   ```bash
   ssh username@mac-studio.local
   git clone https://github.com/yourusername/frontier-llm-mac-stack.git
   cd frontier-llm-mac-stack
   ```

### Step 3: Automated Setup with swissarmyhammer

Once SSH access is configured, use swissarmyhammer to complete the setup:

```bash
# On your MacBook Pro
cd frontier-llm-mac-stack
swissarmyhammer --debug flow run implement
```

**What this does:**
- Reads the implementation plan from `specifications/local-llm-stack-setup.md`
- Executes all setup commands via SSH on Mac Studio
- Sets up Docker containers with Ollama, Prometheus, and Grafana
- Pulls initial model (Qwen2.5-Coder-32B) for testing
- Configures Aider on both machines
- Runs integration tests to verify everything works

**Note:** The automation assumes:
- SSH access is working (test with `ssh username@mac-studio.local`)
- Docker Desktop is installed and running on Mac Studio
- You have sudo privileges on Mac Studio

### Step 4: Verify Installation

After setup completes:

```bash
# Test from MacBook Pro
curl http://mac-studio.local:11434/api/version

# Access monitoring
open http://mac-studio.local:3000  # Grafana
open http://mac-studio.local:9090  # Prometheus
```

## Manual Setup (Alternative)

If you prefer manual setup instead of using swissarmyhammer:

### Option 1: Docker Setup (Recommended)

```bash
# On Mac Studio
cd frontier-llm-mac-stack
./scripts/setup/docker-setup.sh
cp .env.example .env
# Edit .env with your settings
./start.sh
./pull-model.sh
```

### Option 2: Native Installation

```bash
# On Mac Studio
cd frontier-llm-mac-stack
./scripts/setup/01-install-dependencies.sh
./scripts/setup/02-install-ollama.sh
./scripts/setup/03-configure-ollama-service.sh
./scripts/setup/04-pull-models.sh
./scripts/setup/05-install-aider.sh
```

## Stack Selection

This project supports multiple inference engine stacks. Use the `stack-select.sh` script to choose your preferred stack:

```bash
# List available stacks
./stack-select.sh list

# Select the Ollama stack (default)
./stack-select.sh select ollama

# Select the Mistral stack (coming soon)
./stack-select.sh select mistral

# Show current stack
./stack-select.sh current
```

After selecting a stack, use the provided convenience scripts:
```bash
./start.sh               # Start all services
./stop.sh                # Stop all services
./pull-model.sh          # Pull default model
./pull-model.sh llama2   # Pull specific model
```

Or use the docker-compose wrapper directly:
```bash
./docker-compose-wrapper.sh up -d     # Start services
./docker-compose-wrapper.sh ps        # Check status
./docker-compose-wrapper.sh logs -f   # View logs
./docker-compose-wrapper.sh down      # Stop services
```

For detailed information about each stack, see [docs/stacks/](docs/stacks/).

## Architecture

```
┌─────────────────┐         ┌──────────────────┐
│  MacBook Pro    │   LAN   │   Mac Studio     │
│                 ├─────────┤                  │
│ - Aider Client  │         │ - LLM Server     │
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

### Initial Setup Model

**Qwen2.5-Coder:32b** - Start with this for faster setup and testing
```bash
./pull-model.sh qwen2.5-coder:32b-instruct-q8_0
```

### Production Model: Qwen3-235B

Once your setup is working, upgrade to the full Qwen3-235B model:

1. **Check system resources:**
   ```bash
   # Ensure you have ~500GB free space
   df -h /
   
   # Check memory (need 192GB+ for optimal performance)
   sysctl hw.memsize | awk '{print $2/1024/1024/1024 " GB"}'
   ```

2. **Pull Qwen3-235B (when available in Ollama):**
   ```bash
   # This will take significant time and bandwidth
   ./pull-model.sh qwen3:235b-instruct-q8_0
   ```

3. **If Qwen3-235B isn't directly available, see manual conversion:**
   - Instructions in `specifications/local-llm-stack-setup.md` (Appendix C)
   - Requires downloading original weights and converting to GGUF format
   - Consider Q4_K_M or Q5_K_M quantization for size/quality balance

4. **Update Aider configuration:**
   ```bash
   # Edit ~/.aider.conf.yml
   # Change model to: ollama/qwen3:235b-instruct-q5_k_m
   ```

### Other Recommended Models

- **DeepSeek-Coder:33b** - Excellent code understanding
- **CodeLlama:70b** - Meta's largest code model
- **Mixtral:8x7b** - Fast MoE architecture

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

## Project Structure

```
frontier-llm-mac-stack/
├── docker-compose.yml       # Container orchestration
├── .env.example            # Environment configuration template
├── scripts/
│   ├── setup/             # Installation scripts
│   ├── testing/           # Test and benchmark tools
│   └── backup/            # Backup utilities
├── config/                # Service configurations
└── specifications/        # Detailed implementation plans
```

## Troubleshooting SSH Connection

If you can't connect via SSH:

1. **Check Mac Studio is on the same network:**
   ```bash
   # On Mac Studio
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```

2. **Check firewall settings:**
   ```bash
   # On Mac Studio
   sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
   ```

3. **Try IP address instead of hostname:**
   ```bash
   # Find IP on Mac Studio
   ipconfig getifaddr en0
   
   # Connect from MacBook
   ssh username@192.168.x.x
   ```

## Performance Optimization

For best performance with large models:

1. **Disable sleep on Mac Studio:**
   ```bash
   sudo pmset -a sleep 0
   sudo pmset -a disksleep 0
   ```

2. **Increase Docker memory allocation:**
   - Docker Desktop > Settings > Resources
   - Set Memory to 128GB+ for Qwen3-235B

3. **Monitor temperatures:**
   ```bash
   sudo powermetrics --samplers smc | grep -i temp
   ```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License - see [LICENSE](LICENSE) file.