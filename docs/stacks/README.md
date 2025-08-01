# Frontier LLM Stacks

## Overview

The Frontier LLM Mac Stack supports multiple inference engine stacks, allowing you to choose the best solution for your needs. Each stack provides the same monitoring and management capabilities while using different underlying inference engines.

## Available Stacks

### Ollama Stack
- **Status**: ✅ Production Ready
- **Engine**: Ollama
- **Language**: Go
- **Features**: Mature ecosystem, wide model support, active community
- **Best For**: General purpose LLM inference, model experimentation

### Mistral Stack
- **Status**: 🚧 Under Development
- **Engine**: Mistral.rs
- **Language**: Rust
- **Features**: High performance, Metal optimization, efficient memory usage
- **Best For**: Production workloads requiring maximum performance

## Stack Selection

Use the `stack-select.sh` script to switch between stacks:

```bash
# List available stacks
./stack-select.sh list

# Select a stack
./stack-select.sh select ollama

# Show current stack
./stack-select.sh current
```

## Common Components

All stacks share these common components:

- **Monitoring**: Prometheus + Grafana dashboards
- **Metrics**: Node Exporter for system metrics
- **Security**: Nginx reverse proxy
- **Networking**: Shared Docker network

## Directory Structure

```
stacks/
├── common/          # Shared components
│   ├── monitoring/  # Prometheus, Grafana
│   └── nginx/       # Reverse proxy
├── ollama/          # Ollama stack
└── mistral/         # Mistral.rs stack (planned)
```

## Adding a New Stack

To add a new inference engine stack:

1. Create a new directory under `stacks/`
2. Add a `docker-compose.yml` with your inference service
3. Create a `.env.example` with stack-specific variables
4. Add documentation in `docs/stacks/<stack-name>/`
5. Test with `stack-select.sh select <stack-name>`

## Best Practices

1. **API Compatibility**: Maintain Ollama API compatibility where possible
2. **Resource Management**: Use consistent resource limits across stacks
3. **Monitoring**: Integrate with the common monitoring stack
4. **Documentation**: Keep stack-specific docs up to date