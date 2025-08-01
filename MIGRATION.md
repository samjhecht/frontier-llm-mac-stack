# Migration Guide: Multi-Stack Support

## Overview

The Frontier LLM Stack has been refactored to support multiple inference engine stacks. This guide helps existing users migrate to the new structure.

## What's Changed

### Directory Structure
- All stack-specific configurations moved to `stacks/` directory
- Common components (monitoring, nginx) are now shared between stacks
- Original `docker-compose.yml` is now auto-generated

### New Structure
```
frontier-llm-mac-stack/
├── stacks/
│   ├── ollama/          # Ollama-specific config
│   ├── mistral/         # Mistral.rs config (future)
│   └── common/          # Shared components
├── stack-select.sh      # Stack selection tool
└── docker-compose.yml   # Auto-generated
```

## Migration Steps

### 1. Stop Existing Services
If you have services running with the old structure:
```bash
docker-compose down
```

### 2. Pull Latest Changes
```bash
git pull origin main
```

### 3. Select Ollama Stack
```bash
./stack-select.sh select ollama
```

### 4. Review Environment Configuration
The script will create a new `.env` file from the stack-specific template. Review and update with your custom settings:
```bash
# Compare with your old .env if you have custom settings
diff .env.example .env
```

### 5. Start Services
```bash
./start.sh
```

## What's Preserved

- All your models and data remain unchanged
- API endpoints stay the same
- Grafana dashboards and Prometheus data are preserved
- Your custom configurations can be copied to the new `.env`

## New Features

### Stack Selection
Switch between inference engines easily:
```bash
./stack-select.sh list    # See available stacks
./stack-select.sh select mistral  # Switch stacks (when available)
```

### Convenience Scripts
- `./start.sh` - Start the selected stack
- `./stop.sh` - Stop all services
- `./pull-model.sh` - Pull models for the current stack

### Direct Docker Compose Access
Use the wrapper for direct docker-compose commands:
```bash
./docker-compose-wrapper.sh logs -f ollama
./docker-compose-wrapper.sh exec ollama bash
```

## Troubleshooting

### Issue: "No stack selected" Error
**Solution**: Run `./stack-select.sh select ollama`

### Issue: Services Won't Start
**Solution**: Check that Docker network exists:
```bash
docker network create frontier-llm-network
```

### Issue: Missing Environment Variables
**Solution**: Copy missing variables from your old `.env`:
```bash
# Add any custom variables to the new .env
echo "CUSTOM_VAR=value" >> .env
```

## Rollback (If Needed)

To rollback to the previous structure:
```bash
git checkout <previous-commit-hash>
docker-compose up -d
```

## Questions?

- Check the [documentation](docs/stacks/)
- Review the [README](README.md)
- Submit an issue if you encounter problems