# Step 3: Docker Environment Initialization

## Overview
Set up Docker Desktop on Mac Studio and prepare the Docker environment for the LLM stack deployment. This includes configuring Docker resources and testing basic functionality.

## Tasks
1. Install Docker Desktop via Homebrew if not present
2. Configure Docker Desktop resources for optimal LLM performance
3. Test Docker and Docker Compose functionality
4. Set up Docker daemon configuration for remote access

## Implementation Details

### Create script: `scripts/setup/00-docker-init.sh`
```bash
#!/bin/bash
# Tasks:
# 1. Check Docker Desktop installation
# 2. If missing, install via: brew install --cask docker
# 3. Configure Docker resources via ~/Library/Group\ Containers/group.com.docker/settings.json
# 4. Set memory to 80% of system RAM
# 5. Enable experimental features
# 6. Test Docker functionality
```

### Docker Desktop Configuration
Recommended settings for Mac Studio:
```json
{
  "memoryMiB": 65536,  // 64GB for 128GB system
  "cpus": 16,          // Adjust based on M2 Ultra cores
  "diskSizeMiB": 102400, // 100GB
  "filesharingDirectories": [
    "/Users",
    "/Volumes",
    "/tmp"
  ]
}
```

## Dependencies
- Step 1: Prerequisites validated
- Step 2: SSH connectivity verified

## Success Criteria
- Docker Desktop installed and running
- `docker --version` returns 24.0+
- `docker compose version` returns 2.20+
- Docker can pull and run test container
- Sufficient resources allocated to Docker

## Testing
```bash
# Test commands:
docker run --rm hello-world
docker compose version
docker system info
```

## Notes
- Docker Desktop must be started manually on Mac Studio after installation
- User may need to adjust resource allocation based on their specific Mac Studio configuration