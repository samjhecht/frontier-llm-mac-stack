# Mistral Stack Documentation

## Overview

The Mistral stack provides a high-performance LLM inference solution using Mistral.rs as the inference engine. This stack is designed for Mac Studio systems with a focus on performance and efficiency.

## Status

⚠️ **This stack is under development and not yet functional.**

## Planned Components

- **Mistral.rs Server**: Rust-based LLM inference engine
- **API Compatibility Layer**: Ollama-compatible API endpoints
- **Monitoring**: Prometheus, Grafana, and Node Exporter integration
- **Nginx**: Reverse proxy for secure API access

## Planned Features

- Native Metal Performance Shaders support
- Optimized memory management
- Support for Mistral model formats
- API compatibility with Ollama for seamless switching

## Configuration (Planned)

### Environment Variables

The Mistral stack will use the following key environment variables:

- `MISTRAL_MODELS_PATH`: Path to store models
- `MISTRAL_HOST`: Host and port for API
- `MISTRAL_MODEL_PATH`: Internal model path

### Resource Limits

Default resource allocations:
- Memory Limit: 64GB
- Memory Reservation: 32GB
- GPU: Metal Performance Shaders

## Development Status

Track progress in the issues:
- `000003_MISTRAL_docker_image_creation.md`
- `000004_MISTRAL_compose_configuration.md`
- `000005_MISTRAL_api_compatibility_layer.md`

## Contributing

See the main project CONTRIBUTING.md for guidelines on helping develop this stack.