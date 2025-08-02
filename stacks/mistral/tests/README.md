# Mistral.rs Integration Test Suite

This directory contains comprehensive integration tests for the Mistral.rs stack, ensuring feature parity with Ollama and validating all component integrations.

## Test Suite Overview

### 1. **Integration Tests** (`integration-test.sh`)
Comprehensive tests covering:
- API health and basic functionality
- Ollama API compatibility endpoints
- OpenAI API compatibility 
- Error handling and edge cases
- Streaming response validation

### 2. **Aider Integration Tests** (`test-aider-advanced.sh`)
Advanced tests for Aider compatibility:
- Basic code generation
- Multiple file handling
- Context window management
- Code refactoring capabilities
- Error correction
- Documentation generation
- Long conversation handling

### 3. **Monitoring Integration Tests** (`test-monitoring-advanced.sh`)
Validates monitoring stack integration:
- Prometheus connectivity and scraping
- Mistral metrics collection
- Grafana dashboard functionality
- Alerting rules validation
- Performance metrics accuracy

### 4. **Performance Benchmark** (`benchmark-comparison.sh`)
Comprehensive performance testing:
- Latency benchmarks with different prompt sizes
- Throughput testing with concurrent requests
- Streaming response time measurements
- Memory and resource usage tracking
- Optional comparison with Ollama

## Quick Start

### Run All Tests
```bash
./run-all-tests.sh
```

### Run Specific Test Suite
```bash
# Run only integration tests
./run-all-tests.sh integration

# Run only Aider tests
./run-all-tests.sh aider

# Run only monitoring tests
./run-all-tests.sh monitoring

# Run only performance benchmark
./run-all-tests.sh benchmark
```

### Run with Options
```bash
# Verbose output
./run-all-tests.sh -v

# Skip benchmark tests (faster)
./run-all-tests.sh -s

# Use different model
./run-all-tests.sh -m mistral:latest

# Combine options
./run-all-tests.sh -v -s -m qwen2.5-coder:32b integration
```

## Individual Test Scripts

Each test script can also be run independently:

```bash
# Run integration tests only
./integration-test.sh

# Run specific integration test section
./integration-test.sh api      # API health tests only
./integration-test.sh ollama   # Ollama compatibility only
./integration-test.sh aider    # Aider integration only

# Run Aider advanced tests
./test-aider-advanced.sh

# Run monitoring tests
./test-monitoring-advanced.sh

# Run performance benchmark
./benchmark-comparison.sh --iterations 20 --concurrent 10
```

## Test Results

Test results are saved in the `results/` directory:
- Test execution logs
- Performance benchmark CSV files
- Summary reports with timestamps

## Prerequisites

1. **Mistral.rs Stack Running**
   ```bash
   cd ../../../
   ./start.sh
   ```

2. **Model Available**
   ```bash
   # Check available models
   curl http://localhost:11434/api/tags | jq '.models[].name'
   
   # Pull model if needed
   ./pull-model.sh qwen2.5-coder:32b
   ```

3. **Aider Installed** (for Aider tests)
   ```bash
   pip install aider-chat
   ```

4. **Monitoring Stack Running** (for monitoring tests)
   ```bash
   cd ../../../
   ./scripts/monitoring-start.sh
   ```

## Environment Variables

- `TEST_MODEL`: Model to use for testing (default: `qwen2.5-coder:32b`)
- `MISTRAL_HOST`: Mistral host (default: `localhost`)
- `MISTRAL_PORT`: Mistral port (default: `8080`)
- `OLLAMA_PROXY_PORT`: Ollama API proxy port (default: `11434`)
- `PROMETHEUS_PORT`: Prometheus port (default: `9090`)
- `GRAFANA_PORT`: Grafana port (default: `3000`)

## CI/CD Integration

The test suite is designed for CI/CD integration:

```bash
# Run in CI with non-zero exit code on failure
./run-all-tests.sh || exit 1

# Quick smoke test (skip benchmarks)
./run-all-tests.sh -s

# Generate JUnit-style report (coming soon)
./run-all-tests.sh --junit-output results/junit.xml
```

## Troubleshooting

### Tests Failing

1. **Check Services Running**
   ```bash
   docker ps | grep mistral
   ```

2. **Check Model Availability**
   ```bash
   curl http://localhost:11434/api/tags
   ```

3. **Check Logs**
   ```bash
   docker logs frontier-mistral-ollama-proxy
   ```

4. **Run Verbose Mode**
   ```bash
   ./run-all-tests.sh -v
   ```

### Performance Issues

- Ensure sufficient system resources
- Check if other applications are using GPU/CPU
- Reduce concurrent requests in benchmark
- Use smaller test model for faster tests

## Contributing

When adding new tests:

1. Follow the existing test structure
2. Use consistent color coding and output format
3. Include proper error handling
4. Add documentation for new test sections
5. Update this README with new test information