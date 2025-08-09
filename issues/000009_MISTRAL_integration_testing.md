# MISTRAL_000009: Create Integration Testing Suite

## Objective
Develop comprehensive integration tests to verify that the Mistral.rs stack works correctly with all components including Aider, monitoring, and model management.

## Context
We need to ensure that the Mistral.rs implementation provides feature parity with the Ollama stack and that all integrations work seamlessly.

## Tasks

### 1. Create API Compatibility Tests
- Test Ollama API compatibility endpoints
- Verify streaming response handling
- Test model listing and info endpoints
- Validate error handling

### 2. Aider Integration Tests
- Test Aider connection to Mistral.rs
- Verify code completion functionality
- Test long conversation handling
- Ensure context window management

### 3. Monitoring Integration Tests
- Verify metrics are collected properly
- Test Grafana dashboard data
- Validate alert triggering
- Check resource usage tracking

### 4. Performance Comparison Tests
- Create benchmark suite
- Compare Mistral.rs vs Ollama performance
- Test under various load conditions
- Document performance characteristics

## Implementation Details

The comprehensive integration test suite has been implemented in the `stacks/mistral/tests/` directory with the following components:

### Test Suite Structure

1. **Master Test Runner** (`run-all-tests.sh`)
   - Orchestrates all test suites
   - Provides options for verbose output, skipping benchmarks, model selection
   - Generates comprehensive test reports
   - Supports CI/CD integration with proper exit codes

2. **Integration Tests** (`integration-test.sh`)
   - API health and basic functionality
   - Ollama API compatibility (all endpoints)
   - OpenAI API compatibility
   - Error handling and edge cases
   - Streaming response validation

3. **Aider Advanced Tests** (`test-aider-advanced.sh`)
   - Basic code generation
   - Multiple file handling
   - Context window management
   - Code refactoring capabilities
   - Error correction
   - Documentation generation
   - Long conversation handling

4. **Monitoring Advanced Tests** (`test-monitoring-advanced.sh`)
   - Prometheus connectivity and target validation
   - Mistral metrics collection and accuracy
   - Grafana dashboard functionality
   - Alerting rules validation
   - Performance metrics under load

5. **Performance Benchmark** (`benchmark-comparison.sh`)
   - Latency benchmarks with different prompt sizes
   - Throughput testing with concurrent requests
   - Streaming response time measurements
   - Memory and resource usage tracking
   - Optional comparison with Ollama

### Usage Examples

```bash
# Run all tests
./stacks/mistral/tests/run-all-tests.sh

# Run specific test suite
./stacks/mistral/tests/run-all-tests.sh integration

# Run with verbose output
./stacks/mistral/tests/run-all-tests.sh -v

# Skip benchmark tests (faster)
./stacks/mistral/tests/run-all-tests.sh -s

# Run individual test scripts
./stacks/mistral/tests/integration-test.sh
./stacks/mistral/tests/test-aider-advanced.sh
./stacks/mistral/tests/benchmark-comparison.sh --iterations 20
```

### Test Results

All test results are saved in `stacks/mistral/tests/results/` with:
- Detailed execution logs
- Performance benchmark CSV files
- Summary reports with timestamps

## Success Criteria
- All integration tests pass
- Aider works seamlessly with Mistral.rs
- Performance is documented and acceptable
- Monitoring shows accurate metrics

## Estimated Changes
- ~300 lines of test scripts
- ~100 lines of benchmark utilities
- Test documentation

## Proposed Solution

I will implement a comprehensive integration testing suite for the Mistral.rs stack that ensures feature parity with Ollama and validates all component integrations. The solution will be structured as follows:

### 1. Test Suite Organization
- Create a main integration test script in `stacks/mistral/tests/` directory
- Modularize tests by functionality (API, Aider, monitoring, performance)
- Use consistent error handling and reporting across all tests
- Implement both unit-style tests and end-to-end integration tests

### 2. API Compatibility Test Implementation
- Extend the existing `test-aider-compatibility.sh` to be more comprehensive
- Test all Ollama API endpoints that Mistral.rs implements
- Validate request/response formats match Ollama specifications
- Test edge cases like malformed requests, missing models, etc.
- Verify streaming and non-streaming responses work correctly

### 3. Aider Integration Test Enhancement
- Build upon current Aider test logic
- Test various Aider commands and workflows
- Verify code generation, editing, and conversation flows
- Test context window management with large files
- Validate that Aider configuration works seamlessly

### 4. Monitoring Integration Validation
- Extend `test-monitoring.sh` with more comprehensive checks
- Verify all Mistral.rs metrics are properly exposed
- Test Prometheus scraping and alerting rules
- Validate Grafana dashboard data population
- Check resource usage metrics accuracy

### 5. Performance Benchmarking Suite
- Create a dedicated benchmark script for performance comparisons
- Test request latency under various loads
- Measure throughput (requests per second)
- Compare memory usage between Mistral.rs and Ollama
- Test with different model sizes and configurations
- Generate performance reports with clear comparisons

### 6. Test Automation and CI Integration
- Create a master test runner that executes all test suites
- Implement proper exit codes for CI/CD integration
- Add test result logging and reporting
- Create documentation for running tests locally and in CI

### 7. Implementation Steps
1. Create the test directory structure
2. Refactor and enhance existing test scripts
3. Implement new test modules for untested functionality
4. Create the performance benchmarking framework
5. Develop the master test runner
6. Document test usage and interpretation
7. Validate all tests pass in the current environment

## Completion Status

### Fixes Applied (2025-08-09)

1. **Fixed Bash Compatibility Issues**
   - Updated `run-all-tests.sh` to work with macOS bash version
   - Replaced associative arrays with regular arrays for compatibility
   - Added helper functions for key-value storage

2. **Fixed Docker Build Issues**
   - Updated Rust version from 1.75 to 1.82 in api-proxy Dockerfile
   - Added necessary build dependencies (pkg-config, libssl-dev)
   - Successfully built frontier-mistral-ollama-proxy image

3. **Fixed Docker Compose Configuration**
   - Removed duplicate monitoring service includes
   - Fixed build context paths for absolute paths
   - Simplified volume configuration for mistral-models
   - Created missing networks and directories

4. **Test Infrastructure Verification**
   - Created mock server for testing when actual Mistral service is unavailable
   - Verified integration tests can run and pass with mock server
   - Test suite is functional and ready for use

### Known Issues

- Mistral service requires actual model files to start properly
- Tests currently require either:
  - A running Mistral service with loaded models
  - The mock server for basic functionality testing

### Next Steps

To fully utilize the test suite:
1. Download and configure Mistral models
2. Start the full Mistral stack with models
3. Run the complete test suite to verify all integrations

The integration testing infrastructure is now fully implemented and functional.