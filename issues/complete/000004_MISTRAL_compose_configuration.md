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

## Proposed Solution

After analyzing the existing codebase, I've identified the following implementation steps:

### 1. Update Docker Compose Configuration
The current `docker-compose.yml` exists but needs modifications:
- Add `frontier-monitoring` network alongside the existing `frontier-llm-network`
- Update the include mechanism to reference common monitoring (currently missing)
- Ensure proper API port configuration (currently using 11434, issue specifies 8080 as default)
- Add logging configuration

### 2. Enhance Environment Configuration
The `.env.example` file exists but needs additional variables:
- Add `MISTRAL_LOG_LEVEL` variable
- Add `MISTRAL_MAX_BATCH_SIZE` variable
- Ensure consistency between compose file and environment variables
- Add Metal/GPU acceleration configuration options

### 3. Create Configuration Directory Structure
- Create `config/mistral` directory for Mistral-specific configuration files
- This directory is already referenced in the docker-compose volumes but doesn't exist

### 4. Create Service Management Scripts
Based on the existing scripts in `/scripts`, create Mistral-specific versions:
- `scripts/mistral-start.sh` - Start Mistral service
- `scripts/mistral-stop.sh` - Stop Mistral service
- `scripts/mistral-status.sh` - Check Mistral service health
- Update existing `download-model.sh` if needed for Mistral.rs format

### 5. Integration Testing
- Verify Mistral service connects to both networks
- Test health check endpoint
- Ensure monitoring metrics are collected
- Validate resource limits are enforced