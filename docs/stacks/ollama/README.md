# Ollama Stack Documentation

## Overview

The Ollama stack provides a complete LLM inference solution using Ollama as the inference engine. This stack is optimized for Mac Studio systems and includes comprehensive monitoring and management capabilities.

## Components

- **Ollama Server**: The main LLM inference engine
- **Monitoring**: Prometheus, Grafana, and Node Exporter for system metrics
- **Nginx**: Reverse proxy for secure API access
- **Aider** (optional): Development environment for AI-assisted coding

## Configuration

### Environment Variables

The Ollama stack uses the following key environment variables:

- `OLLAMA_MODELS_PATH`: Path to store downloaded models (default: `./data/ollama-models`)
- `OLLAMA_HOST`: Host and port for Ollama API (default: `0.0.0.0:11434`)
- `OLLAMA_KEEP_ALIVE`: Time to keep models loaded in memory (default: `10m`)
- `OLLAMA_NUM_PARALLEL`: Number of parallel requests (default: `4`)
- `OLLAMA_MAX_LOADED_MODELS`: Maximum number of models to keep loaded (default: `2`)

### Resource Limits

Default resource allocations:
- Memory Limit: 64GB
- Memory Reservation: 32GB
- GPU: All available NVIDIA GPUs

## Usage

1. Select the Ollama stack:
   ```bash
   ./stack-select.sh select ollama
   ```

2. Configure environment:
   ```bash
   cp .env.example .env
   # Edit .env with your specific settings
   ```

3. Start the stack:
   ```bash
   docker-compose up -d
   ```

4. Pull models:
   ```bash
   ./scripts/setup/04-pull-models.sh
   ```

## API Endpoints

- Ollama API: `http://localhost:11434`
- Grafana Dashboard: `http://localhost:3000`
- Prometheus Metrics: `http://localhost:9090`

## Model Management

List available models:
```bash
curl http://localhost:11434/api/tags
```

Pull a new model:
```bash
curl -X POST http://localhost:11434/api/pull -d '{"name": "llama2"}'
```

## Monitoring

Access Grafana at `http://localhost:3000` with:
- Username: `admin`
- Password: `frontier-llm` (or as configured in .env)

Pre-configured dashboards include:
- System metrics
- Ollama performance metrics
- GPU utilization (if enabled)