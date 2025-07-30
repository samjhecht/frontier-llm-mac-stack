# Step 5: Ollama Service Deployment

## Overview
Deploy the Ollama service using Docker Compose, configure it for optimal performance on Mac Studio, and verify it's accessible both locally and remotely.

## Tasks
1. Deploy Ollama container with proper configuration
2. Configure Mac-specific overrides (no GPU on Mac)
3. Verify service health and API accessibility
4. Test basic API endpoints

## Implementation Details

### Docker Compose Configuration
The main `docker-compose.yml` already defines Ollama service. Need to:

1. **Create Mac-specific override** in `docker-compose.override.yml`:
```yaml
services:
  ollama:
    deploy:
      resources:
        limits:
          memory: ${OLLAMA_MEMORY_LIMIT:-64G}
        reservations:
          memory: ${OLLAMA_MEMORY_RESERVATION:-32G}
    # Remove GPU configuration for Mac
```

2. **Start Ollama service**:
```bash
docker compose up -d ollama
```

3. **Health check implementation**:
```bash
# Wait for Ollama to be ready
until curl -s http://localhost:11434/api/version > /dev/null; do
  echo "Waiting for Ollama..."
  sleep 5
done
```

### API Verification Tests
```bash
# Version check
curl http://localhost:11434/api/version

# List models (should be empty initially)
curl http://localhost:11434/api/tags

# Test generation endpoint (will fail without model)
curl -X POST http://localhost:11434/api/generate \
  -d '{"model": "test", "prompt": "test"}'
```

## Dependencies
- Step 4: Directory structure and configs created
- Docker daemon running

## Success Criteria
- Ollama container running without errors
- API endpoint responding on port 11434
- Service accessible from local network
- Logs show successful initialization
- Memory allocation correct

## Testing
- Check container logs: `docker compose logs ollama`
- Verify API endpoints respond
- Test from MacBook Pro using Mac Studio IP
- Monitor resource usage

## Notes
- Ollama on Mac uses Metal for acceleration (not CUDA)
- Initial startup may take 30-60 seconds
- Models directory should be bind-mounted for persistence