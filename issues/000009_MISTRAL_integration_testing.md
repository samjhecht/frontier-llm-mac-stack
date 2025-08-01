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

```bash
#!/bin/bash
# stacks/mistral/tests/integration-test.sh

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "Starting Mistral.rs Integration Tests..."

# Test 1: API Health Check
test_api_health() {
    echo -n "Testing API health endpoint... "
    if curl -f -s http://localhost:8080/health > /dev/null; then
        echo -e "${GREEN}PASS${NC}"
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

# Test 2: Ollama Compatibility
test_ollama_compat() {
    echo -n "Testing Ollama API compatibility... "
    response=$(curl -s -X POST http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d '{
            "model": "qwen2.5-coder:32b",
            "prompt": "Hello",
            "stream": false
        }')
    
    if echo "$response" | jq -e '.response' > /dev/null; then
        echo -e "${GREEN}PASS${NC}"
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "Response: $response"
        return 1
    fi
}

# Test 3: Aider Connection
test_aider_connection() {
    echo -n "Testing Aider connection... "
    export OLLAMA_API_BASE="http://localhost:11434"
    
    if echo "test" | aider --model ollama/qwen2.5-coder:32b --yes --exit > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

# Test 4: Metrics Collection
test_metrics() {
    echo -n "Testing Prometheus metrics... "
    if curl -s http://localhost:9090/metrics | grep -q "mistral_"; then
        echo -e "${GREEN}PASS${NC}"
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

# Run all tests
run_all_tests() {
    local failed=0
    
    test_api_health || ((failed++))
    test_ollama_compat || ((failed++))
    test_aider_connection || ((failed++))
    test_metrics || ((failed++))
    
    echo ""
    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}$failed tests failed${NC}"
        return 1
    fi
}

# Performance benchmark
run_benchmark() {
    echo "Running performance benchmark..."
    
    # Simple latency test
    total_time=0
    iterations=10
    
    for i in $(seq 1 $iterations); do
        start=$(date +%s.%N)
        curl -s -X POST http://localhost:8080/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d '{
                "model": "qwen2.5-coder:32b",
                "messages": [{"role": "user", "content": "Hi"}],
                "max_tokens": 50
            }' > /dev/null
        end=$(date +%s.%N)
        
        elapsed=$(echo "$end - $start" | bc)
        total_time=$(echo "$total_time + $elapsed" | bc)
        echo "Request $i: ${elapsed}s"
    done
    
    avg_time=$(echo "scale=3; $total_time / $iterations" | bc)
    echo "Average response time: ${avg_time}s"
}

# Main
case "${1:-test}" in
    test)
        run_all_tests
        ;;
    benchmark)
        run_benchmark
        ;;
    *)
        echo "Usage: $0 [test|benchmark]"
        ;;
esac
```

## Success Criteria
- All integration tests pass
- Aider works seamlessly with Mistral.rs
- Performance is documented and acceptable
- Monitoring shows accurate metrics

## Estimated Changes
- ~300 lines of test scripts
- ~100 lines of benchmark utilities
- Test documentation