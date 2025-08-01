# Mistral.rs Stack

This directory contains the Docker Compose configuration for running Mistral.rs inference server as part of the Frontier LLM Stack.

## Quick Start

1. Copy the environment file:
   ```bash
   cp .env.example .env
   ```

2. Download a model:
   ```bash
   ./download-model.sh list-available
   ./download-model.sh download <model-url>
   ```

3. Start the service:
   ```bash
   ../../scripts/mistral-start.sh
   ```

## Configuration

### Environment Variables

Key environment variables (configured in `.env`):

- `MISTRAL_API_PORT`: API port (default: 8080)
- `MISTRAL_MODELS_PATH`: Path to models directory
- `MISTRAL_MEMORY_LIMIT`: Memory limit (default: 64G)
- `MISTRAL_MEMORY_RESERVATION`: Memory reservation (default: 32G)
- `MISTRAL_LOG_LEVEL`: Log level (default: info)
- `MISTRAL_MAX_BATCH_SIZE`: Maximum batch size (default: 8)

### Networks

The Mistral service connects to two networks:
- `frontier-llm-network`: Main network for LLM services
- `frontier-monitoring`: Monitoring infrastructure network

### Health Check

The service includes a health check endpoint at `/health` that verifies the server is running properly.

## Management Scripts

- `../../scripts/mistral-start.sh`: Start the Mistral service
- `../../scripts/mistral-stop.sh`: Stop the Mistral service
- `../../scripts/mistral-status.sh`: Check service status and health

## Model Management

Use the included `download-model.sh` script to download compatible models:

```bash
# List available models
./download-model.sh list-available

# Download a specific model
./download-model.sh download <url>

# Check downloaded models
./download-model.sh check
```

## API Endpoints

- Health: `http://localhost:8080/health`
- Models: `http://localhost:8080/v1/models`
- Chat Completions: `http://localhost:8080/v1/chat/completions`

## Troubleshooting

Check logs:
```bash
docker logs -f frontier-mistral
```

Check resource usage:
```bash
docker stats frontier-mistral
```