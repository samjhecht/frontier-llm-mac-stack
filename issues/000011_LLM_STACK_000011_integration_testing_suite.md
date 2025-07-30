# Step 11: Integration Testing Suite

## Overview
Create a comprehensive integration testing suite that validates the entire LLM stack is working correctly end-to-end, including real coding scenarios with Aider.

## Tasks
1. Create integration test framework
2. Implement service health checks
3. Create real-world coding tests
4. Implement performance benchmarks
5. Create automated test runner

## Implementation Details

### 1. Integration Test Framework
Create `scripts/testing/integration-test-framework.sh`:
```bash
#!/bin/bash
set -euo pipefail

# Test framework with reporting
TEST_RESULTS_DIR="./test-results/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$TEST_RESULTS_DIR"

# Test tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Run test function
run_integration_test() {
    local test_name="$1"
    local test_script="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo "Running: $test_name"
    
    if bash "$test_script" > "$TEST_RESULTS_DIR/${test_name}.log" 2>&1; then
        echo "✓ PASSED: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAILED: $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo "See $TEST_RESULTS_DIR/${test_name}.log for details"
    fi
}
```

### 2. Service Health Integration Test
Create `scripts/testing/integration/test-service-health.sh`:
```bash
#!/bin/bash
set -euo pipefail

echo "=== Service Health Integration Test ==="

# Check all services are running
services=("ollama" "prometheus" "grafana" "nginx" "node-exporter")
for service in "${services[@]}"; do
    if ! docker compose ps | grep -q "$service.*running"; then
        echo "ERROR: $service is not running"
        exit 1
    fi
done

# Check API endpoints
endpoints=(
    "http://localhost:11434/api/version"
    "http://localhost:3000/api/health"
    "http://localhost:9090/-/ready"
    "http://localhost/health"
)

for endpoint in "${endpoints[@]}"; do
    if ! curl -s "$endpoint" > /dev/null; then
        echo "ERROR: $endpoint is not responding"
        exit 1
    fi
done

echo "All services healthy"
```

### 3. Aider Coding Integration Test
Create `scripts/testing/integration/test-aider-coding.sh`:
```bash
#!/bin/bash
set -euo pipefail

echo "=== Aider Coding Integration Test ==="

# Create test project
TEST_DIR="/tmp/aider-integration-test-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"
git init

# Create initial code
cat > calculator.py << 'EOF'
class Calculator:
    def add(self, a, b):
        return a + b
    
    def subtract(self, a, b):
        # TODO: implement
        pass
    
    def multiply(self, a, b):
        # TODO: implement
        pass
    
    def divide(self, a, b):
        # TODO: implement
        pass
EOF

# Test 1: Implement missing methods
aider calculator.py --yes --message "Implement the subtract, multiply, and divide methods. Add proper error handling for divide by zero."

# Verify implementation
if ! python3 -c "
from calculator import Calculator
calc = Calculator()
assert calc.subtract(5, 3) == 2
assert calc.multiply(4, 5) == 20
assert calc.divide(10, 2) == 5
try:
    calc.divide(5, 0)
    assert False, 'Should raise exception'
except (ZeroDivisionError, ValueError):
    pass
print('All tests passed')
"; then
    echo "ERROR: Implementation test failed"
    exit 1
fi

# Test 2: Add unit tests
aider --yes --message "Create a comprehensive test file test_calculator.py with pytest"

# Run the tests
if [[ -f test_calculator.py ]]; then
    pip install pytest > /dev/null 2>&1
    pytest test_calculator.py
fi

# Cleanup
cd /
rm -rf "$TEST_DIR"
```

### 4. Performance Benchmark Test
Create `scripts/testing/integration/test-performance-benchmark.sh`:
```bash
#!/bin/bash
set -euo pipefail

echo "=== Performance Benchmark Test ==="

# Benchmark configuration
PROMPTS=(
    "Write a recursive fibonacci function in Python"
    "Create a REST API endpoint using FastAPI"
    "Implement a binary search tree in Python"
)

# Run benchmarks
for prompt in "${PROMPTS[@]}"; do
    echo "Benchmarking: $prompt"
    
    start_time=$(date +%s.%N)
    response=$(curl -s -X POST http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"qwen2.5-coder:32b-instruct-q8_0\",
            \"prompt\": \"$prompt\",
            \"stream\": false,
            \"options\": {\"num_predict\": 200}
        }")
    end_time=$(date +%s.%N)
    
    # Calculate metrics
    duration=$(echo "$end_time - $start_time" | bc)
    tokens=$(echo "$response" | jq -r '.response' | wc -w)
    tokens_per_second=$(echo "scale=2; $tokens / $duration" | bc)
    
    echo "  Duration: ${duration}s"
    echo "  Tokens: $tokens"
    echo "  Tokens/second: $tokens_per_second"
    
    # Check performance threshold
    if (( $(echo "$tokens_per_second < 5" | bc -l) )); then
        echo "WARNING: Low performance detected"
    fi
done
```

### 5. End-to-End Test Runner
Update `scripts/testing/test-integration.sh`:
```bash
#!/bin/bash
set -euo pipefail

echo "=== Running Full Integration Test Suite ==="

# Source test framework
source scripts/testing/integration-test-framework.sh

# Run all integration tests
run_integration_test "service-health" "scripts/testing/integration/test-service-health.sh"
run_integration_test "remote-connectivity" "scripts/testing/test-remote-connectivity.sh"
run_integration_test "aider-coding" "scripts/testing/integration/test-aider-coding.sh"
run_integration_test "performance-benchmark" "scripts/testing/integration/test-performance-benchmark.sh"
run_integration_test "monitoring-metrics" "scripts/testing/integration/test-monitoring-metrics.sh"

# Generate report
cat > "$TEST_RESULTS_DIR/summary.txt" << EOF
Integration Test Summary
========================
Total Tests: $TESTS_RUN
Passed: $TESTS_PASSED
Failed: $TESTS_FAILED
Success Rate: $(echo "scale=2; $TESTS_PASSED * 100 / $TESTS_RUN" | bc)%

Test Run: $(date)
Results: $TEST_RESULTS_DIR
EOF

cat "$TEST_RESULTS_DIR/summary.txt"

# Exit with appropriate code
[[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1
```

## Dependencies
- All previous steps completed
- All services running and configured
- Aider installed and configured

## Success Criteria
- All integration tests pass
- Performance meets thresholds
- Real coding scenarios work correctly
- Monitoring shows expected metrics
- Test results are properly logged

## Testing
```bash
# Run full integration suite
./scripts/testing/test-integration.sh

# Run individual tests
./scripts/testing/integration/test-service-health.sh
./scripts/testing/integration/test-aider-coding.sh
```

## Notes
- Integration tests should run in CI/CD pipeline
- Consider adding more complex coding scenarios
- Performance thresholds may need adjustment
- Keep test data for trend analysis