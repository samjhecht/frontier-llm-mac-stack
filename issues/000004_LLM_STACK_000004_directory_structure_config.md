# Step 4: Directory Structure and Configuration Files

## Overview
Create the complete directory structure and base configuration files needed for the LLM stack. This establishes the foundation for all services and ensures proper organization.

## Tasks
1. Create comprehensive directory structure
2. Generate environment configuration from template
3. Create base configuration files for all services
4. Set proper permissions on directories

## Implementation Details

### Directory Structure
```
frontier-llm-mac-stack/
├── config/
│   ├── ollama/
│   ├── prometheus/
│   │   └── prometheus.yml
│   ├── grafana/
│   │   ├── provisioning/
│   │   │   ├── datasources/
│   │   │   └── dashboards/
│   │   └── dashboards/
│   ├── nginx/
│   │   └── default.conf
│   ├── ssl/
│   └── aider/
├── data/
│   └── ollama-models/
├── docker/
│   └── aider/
│       ├── Dockerfile
│       └── aider.conf.yml
├── logs/
├── scripts/
│   ├── validation/
│   ├── setup/
│   ├── backup/
│   ├── monitoring/
│   └── testing/
└── .env
```

### Key Configuration Files

1. **`.env` file customization**:
   - Set `OLLAMA_MODELS_PATH` to Mac Studio home directory path
   - Configure memory limits based on system specs
   - Set appropriate network ports

2. **Prometheus configuration** (`config/prometheus/prometheus.yml`):
   - Scrape configs for Ollama metrics
   - Node exporter configuration
   - Alert rules preparation

3. **Grafana provisioning**:
   - Datasource configuration for Prometheus
   - Dashboard provisioning setup
   - Default Ollama monitoring dashboard

## Dependencies
- Step 3: Docker environment initialized

## Success Criteria
- All directories created with correct permissions
- Configuration files generated and customized
- Environment variables properly set
- No hardcoded paths - all configurable

## Testing
- Verify directory structure with `tree` command
- Check file permissions
- Validate YAML syntax in configuration files
- Ensure .env file has all required variables