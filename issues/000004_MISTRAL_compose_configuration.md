# MISTRAL_000004: Create Mistral.rs Docker Compose Configuration

## Objective
Create a complete Docker Compose configuration for the Mistral.rs stack that integrates with the common monitoring infrastructure.

## Context
The Mistral.rs stack needs its own docker-compose.yml that defines the inference service and connects it to the shared monitoring network.

## Tasks

### 1. Create Main Docker Compose File
- Create `stacks/mistral/docker-compose.yml`
- Define mistral service with proper resource limits
- Configure volume mounts for models and configuration
- Set up networking to connect with monitoring

### 2. Create Environment Configuration
- Create `stacks/mistral/.env.example`
- Define Mistral.rs-specific environment variables
- Include model paths, API ports, and resource limits
- Add configuration for Metal/GPU acceleration

### 3. Configure Service Dependencies
- Link to common monitoring network
- Set up health checks
- Configure restart policies
- Add logging configuration

### 4. Create Helper Scripts
- Adapt existing helper scripts for Mistral.rs
- Create model pulling script for Mistral.rs format
- Add service management scripts

## Implementation Details

```yaml
# stacks/mistral/docker-compose.yml
version: '3.8'

services:
  mistral:
    build:
      context: ./docker
      dockerfile: Dockerfile
    container_name: frontier-mistral
    restart: unless-stopped
    ports:
      - "${MISTRAL_API_PORT:-8080}:8080"
    volumes:
      - mistral-models:/models
      - ./config:/config
    environment:
      - MISTRAL_MODELS_PATH=/models
      - MISTRAL_HOST=0.0.0.0:8080
      - MISTRAL_LOG_LEVEL=${MISTRAL_LOG_LEVEL:-info}
      - MISTRAL_MAX_BATCH_SIZE=${MISTRAL_MAX_BATCH_SIZE:-8}
    deploy:
      resources:
        limits:
          memory: ${MISTRAL_MEMORY_LIMIT:-64G}
        reservations:
          memory: ${MISTRAL_MEMORY_RESERVATION:-32G}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - frontier-inference
      - frontier-monitoring

  # Include common monitoring
  include:
    - ../common/docker-compose.monitoring.yml

volumes:
  mistral-models:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${MISTRAL_MODELS_PATH:-./data/mistral-models}

networks:
  frontier-inference:
    name: frontier-inference-mistral
  frontier-monitoring:
    external: true
```

## Success Criteria
- Mistral.rs service starts successfully via docker-compose
- Service connects to monitoring infrastructure
- Resource limits are properly enforced
- Health checks pass consistently

## Estimated Changes
- ~150 lines of Docker Compose configuration
- ~50 lines of environment configuration
- Helper script adaptations