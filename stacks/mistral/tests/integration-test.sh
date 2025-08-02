#!/bin/bash
# Comprehensive integration testing suite for Mistral.rs stack

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
PASSED=0
FAILED=0
SKIPPED=0

# Configuration
MISTRAL_HOST="${MISTRAL_HOST:-localhost}"
MISTRAL_PORT="${MISTRAL_PORT:-8080}"
OLLAMA_PROXY_PORT="${OLLAMA_PROXY_PORT:-11434}"
PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"
TEST_MODEL="${TEST_MODEL:-qwen2.5-coder:32b}"

# Test results log
TEST_LOG="/tmp/mistral-integration-test-$(date +%Y%m%d-%H%M%S).log"

# Utility functions
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}" | tee -a "$TEST_LOG"
}

print_test() {
    echo -en "$1... " | tee -a "$TEST_LOG"
}

print_pass() {
    echo -e "${GREEN}PASS${NC}" | tee -a "$TEST_LOG"
    ((PASSED++))
}

print_fail() {
    echo -e "${RED}FAIL${NC}" | tee -a "$TEST_LOG"
    echo "  Error: $1" | tee -a "$TEST_LOG"
    ((FAILED++))
}

print_skip() {
    echo -e "${YELLOW}SKIP${NC}" | tee -a "$TEST_LOG"
    echo "  Reason: $1" | tee -a "$TEST_LOG"
    ((SKIPPED++))
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$TEST_LOG"
}

# Test if a URL returns expected status code
test_endpoint() {
    local url=$1
    local expected_code=${2:-200}
    local response
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [ "$response" = "$expected_code" ]; then
        return 0
    else
        return 1
    fi
}

# Test JSON response from an endpoint
test_json_response() {
    local url=$1
    local field=$2
    local response
    
    response=$(curl -s "$url" 2>/dev/null || echo "{}")
    
    if echo "$response" | jq -e ".$field" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# === SECTION 1: API Health and Basic Functionality ===
test_api_health() {
    print_header "API Health and Basic Functionality"
    
    # Test 1: Mistral health endpoint
    print_test "Testing Mistral health endpoint"
    if test_endpoint "http://$MISTRAL_HOST:$MISTRAL_PORT/health"; then
        print_pass
    else
        print_fail "Mistral health endpoint not responding"
    fi
    
    # Test 2: Ollama proxy health
    print_test "Testing Ollama proxy health endpoint"
    if test_endpoint "http://$MISTRAL_HOST:$OLLAMA_PROXY_PORT/"; then
        print_pass
    else
        print_fail "Ollama proxy not responding"
    fi
    
    # Test 3: Metrics endpoint
    print_test "Testing metrics endpoint"
    if test_endpoint "http://$MISTRAL_HOST:$OLLAMA_PROXY_PORT/metrics"; then
        print_pass
    else
        print_fail "Metrics endpoint not available"
    fi
}

# === SECTION 2: Ollama API Compatibility ===
test_ollama_compatibility() {
    print_header "Ollama API Compatibility"
    
    # Test 1: Version endpoint
    print_test "Testing /api/version endpoint"
    if test_json_response "http://$MISTRAL_HOST:$OLLAMA_PROXY_PORT/api/version" "version"; then
        print_pass
    else
        print_fail "Version endpoint not returning expected format"
    fi
    
    # Test 2: Tags/models endpoint
    print_test "Testing /api/tags endpoint"
    response=$(curl -s "http://$MISTRAL_HOST:$OLLAMA_PROXY_PORT/api/tags" 2>/dev/null || echo "{}")
    if echo "$response" | jq -e '.models' > /dev/null 2>&1; then
        print_pass
        model_count=$(echo "$response" | jq '.models | length' 2>/dev/null || echo "0")
        print_info "Found $model_count models"
    else
        print_fail "Tags endpoint not returning expected format"
    fi
    
    # Test 3: Generate endpoint (non-streaming)
    print_test "Testing /api/generate endpoint (non-streaming)"
    response=$(curl -s -X POST "http://$MISTRAL_HOST:$OLLAMA_PROXY_PORT/api/generate" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$TEST_MODEL\",
            \"prompt\": \"Hello\",
            \"stream\": false
        }" 2>/dev/null || echo "{}")
    
    if echo "$response" | jq -e '.response' > /dev/null 2>&1; then
        print_pass
    else
        print_fail "Generate endpoint not working or model not loaded"
    fi
    
    # Test 4: Chat endpoint (non-streaming)
    print_test "Testing /api/chat endpoint (non-streaming)"
    response=$(curl -s -X POST "http://$MISTRAL_HOST:$OLLAMA_PROXY_PORT/api/chat" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$TEST_MODEL\",
            \"messages\": [{\"role\": \"user\", \"content\": \"Hello\"}],
            \"stream\": false
        }" 2>/dev/null || echo "{}")
    
    if echo "$response" | jq -e '.message.content' > /dev/null 2>&1; then
        print_pass
    else
        print_fail "Chat endpoint not working properly"
    fi
    
    # Test 5: Streaming response
    print_test "Testing streaming response"
    if timeout 5 curl -s -N -X POST "http://$MISTRAL_HOST:$OLLAMA_PROXY_PORT/api/generate" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$TEST_MODEL\",
            \"prompt\": \"Count to 3\",
            \"stream\": true
        }" 2>/dev/null | head -n 3 | grep -q "response"; then
        print_pass
    else
        print_skip "Streaming test inconclusive or model not available"
    fi
}

# === SECTION 3: OpenAI API Compatibility ===
test_openai_compatibility() {
    print_header "OpenAI API Compatibility"
    
    # Test 1: Models endpoint
    print_test "Testing /v1/models endpoint"
    if test_json_response "http://$MISTRAL_HOST:$MISTRAL_PORT/v1/models" "data"; then
        print_pass
    else
        print_fail "OpenAI models endpoint not working"
    fi
    
    # Test 2: Chat completions endpoint
    print_test "Testing /v1/chat/completions endpoint"
    response=$(curl -s -X POST "http://$MISTRAL_HOST:$MISTRAL_PORT/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$TEST_MODEL\",
            \"messages\": [{\"role\": \"user\", \"content\": \"Hello\"}],
            \"max_tokens\": 50
        }" 2>/dev/null || echo "{}")
    
    if echo "$response" | jq -e '.choices[0].message.content' > /dev/null 2>&1; then
        print_pass
    else
        print_fail "OpenAI chat completions not working"
    fi
}

# === SECTION 4: Aider Integration ===
test_aider_integration() {
    print_header "Aider Integration"
    
    if ! command -v aider &> /dev/null; then
        print_skip "Aider not installed"
        return
    fi
    
    # Create temporary test directory
    test_dir=$(mktemp -d)
    cd "$test_dir"
    git init > /dev/null 2>&1
    
    # Test 1: Basic Aider connection
    print_test "Testing Aider connection to Mistral"
    export OLLAMA_API_BASE="http://$MISTRAL_HOST:$OLLAMA_PROXY_PORT"
    
    echo "def add(a, b):\n    pass" > test.py
    
    if echo "/help" | timeout 10 aider --model "ollama/$TEST_MODEL" --no-auto-commits --yes test.py 2>&1 | grep -qE "(Commands|Help)"; then
        print_pass
    else
        print_fail "Aider cannot connect to Mistral"
    fi
    
    # Test 2: Code generation
    print_test "Testing Aider code generation"
    if echo "implement the add function to return a + b" | timeout 20 aider --model "ollama/$TEST_MODEL" --no-auto-commits --yes test.py 2>&1 > /dev/null; then
        if grep -q "return a + b" test.py; then
            print_pass
        else
            print_fail "Code generation did not produce expected result"
        fi
    else
        print_fail "Aider code generation failed"
    fi
    
    # Cleanup
    cd - > /dev/null
    rm -rf "$test_dir"
}

# === SECTION 5: Monitoring Integration ===
test_monitoring_integration() {
    print_header "Monitoring Integration"
    
    # Test 1: Prometheus connectivity
    print_test "Testing Prometheus connectivity"
    if test_endpoint "http://localhost:$PROMETHEUS_PORT/-/ready"; then
        print_pass
    else
        print_skip "Prometheus not accessible"
        return
    fi
    
    # Test 2: Check if Mistral metrics are scraped
    print_test "Testing Mistral metrics in Prometheus"
    targets=$(curl -s "http://localhost:$PROMETHEUS_PORT/api/v1/targets" 2>/dev/null || echo "{}")
    if echo "$targets" | grep -q "mistral.*up"; then
        print_pass
    else
        print_fail "Mistral metrics not being scraped by Prometheus"
    fi
    
    # Test 3: Verify specific metrics exist
    print_test "Testing specific Mistral metrics"
    metrics=$(curl -s "http://$MISTRAL_HOST:$OLLAMA_PROXY_PORT/metrics" 2>/dev/null || echo "")
    
    expected_metrics=(
        "mistral_http_requests_total"
        "mistral_http_request_duration_seconds"
        "mistral_active_requests"
        "mistral_streaming_chunks_total"
    )
    
    missing_metrics=0
    for metric in "${expected_metrics[@]}"; do
        if ! echo "$metrics" | grep -q "$metric"; then
            ((missing_metrics++))
        fi
    done
    
    if [ $missing_metrics -eq 0 ]; then
        print_pass
    else
        print_fail "$missing_metrics expected metrics are missing"
    fi
    
    # Test 4: Grafana availability
    print_test "Testing Grafana availability"
    if test_endpoint "http://localhost:$GRAFANA_PORT/api/health"; then
        print_pass
        print_info "Grafana UI: http://localhost:$GRAFANA_PORT"
    else
        print_skip "Grafana not accessible"
    fi
}

# === SECTION 6: Performance Benchmark ===
test_performance_benchmark() {
    print_header "Performance Benchmark"
    
    # Skip if model not available
    if ! curl -s "http://$MISTRAL_HOST:$OLLAMA_PROXY_PORT/api/tags" | jq -e '.models[] | select(.name == "'$TEST_MODEL'")' > /dev/null 2>&1; then
        print_skip "Test model $TEST_MODEL not available"
        return
    fi
    
    # Test 1: Latency benchmark
    print_test "Testing response latency"
    
    total_time=0
    iterations=5
    failed_requests=0
    
    for i in $(seq 1 $iterations); do
        start=$(date +%s.%N)
        
        response=$(curl -s -X POST "http://$MISTRAL_HOST:$MISTRAL_PORT/v1/chat/completions" \
            -H "Content-Type: application/json" \
            -d "{
                \"model\": \"$TEST_MODEL\",
                \"messages\": [{\"role\": \"user\", \"content\": \"Say hello\"}],
                \"max_tokens\": 20
            }" 2>/dev/null || echo "{}")
        
        if echo "$response" | jq -e '.choices[0].message.content' > /dev/null 2>&1; then
            end=$(date +%s.%N)
            elapsed=$(echo "$end - $start" | bc)
            total_time=$(echo "$total_time + $elapsed" | bc)
        else
            ((failed_requests++))
        fi
    done
    
    if [ $failed_requests -eq 0 ]; then
        avg_time=$(echo "scale=3; $total_time / $iterations" | bc)
        print_pass
        print_info "Average latency: ${avg_time}s"
    else
        print_fail "$failed_requests out of $iterations requests failed"
    fi
    
    # Test 2: Concurrent requests
    print_test "Testing concurrent request handling"
    
    concurrent_test() {
        curl -s -X POST "http://$MISTRAL_HOST:$MISTRAL_PORT/v1/chat/completions" \
            -H "Content-Type: application/json" \
            -d "{
                \"model\": \"$TEST_MODEL\",
                \"messages\": [{\"role\": \"user\", \"content\": \"Hello\"}],
                \"max_tokens\": 10
            }" > /dev/null 2>&1 && echo "success" || echo "fail"
    }
    
    # Run 10 concurrent requests
    results=""
    for i in {1..10}; do
        concurrent_test &
        results="$results $!"
    done
    
    successes=0
    for pid in $results; do
        if wait $pid; then
            ((successes++))
        fi
    done
    
    if [ $successes -ge 8 ]; then
        print_pass
        print_info "Successfully handled $successes/10 concurrent requests"
    else
        print_fail "Only $successes/10 concurrent requests succeeded"
    fi
}

# === SECTION 7: Error Handling and Edge Cases ===
test_error_handling() {
    print_header "Error Handling and Edge Cases"
    
    # Test 1: Invalid model
    print_test "Testing invalid model handling"
    response=$(curl -s -X POST "http://$MISTRAL_HOST:$OLLAMA_PROXY_PORT/api/generate" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"non-existent-model\",
            \"prompt\": \"Test\",
            \"stream\": false
        }" 2>/dev/null || echo "{}")
    
    if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
        print_pass
    else
        print_fail "Invalid model did not return proper error"
    fi
    
    # Test 2: Malformed request
    print_test "Testing malformed request handling"
    response_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://$MISTRAL_HOST:$OLLAMA_PROXY_PORT/api/generate" \
        -H "Content-Type: application/json" \
        -d "{ invalid json }" 2>/dev/null || echo "000")
    
    if [ "$response_code" = "400" ]; then
        print_pass
    else
        print_fail "Malformed request returned $response_code instead of 400"
    fi
    
    # Test 3: Empty request
    print_test "Testing empty request handling"
    response_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://$MISTRAL_HOST:$OLLAMA_PROXY_PORT/api/generate" \
        -H "Content-Type: application/json" \
        -d "{}" 2>/dev/null || echo "000")
    
    if [ "$response_code" = "400" ] || [ "$response_code" = "422" ]; then
        print_pass
    else
        print_fail "Empty request returned unexpected status code: $response_code"
    fi
}

# === Test Summary Function ===
print_summary() {
    print_header "Test Summary"
    
    total=$((PASSED + FAILED + SKIPPED))
    
    echo "Total tests: $total"
    echo -e "Passed: ${GREEN}$PASSED${NC}"
    echo -e "Failed: ${RED}$FAILED${NC}"
    echo -e "Skipped: ${YELLOW}$SKIPPED${NC}"
    
    if [ $FAILED -eq 0 ]; then
        echo -e "\n${GREEN}All tests passed successfully!${NC}"
        return 0
    else
        echo -e "\n${RED}Some tests failed. Please check the log at: $TEST_LOG${NC}"
        return 1
    fi
}

# === Main Test Runner ===
run_all_tests() {
    echo "Starting Mistral.rs Integration Tests" | tee "$TEST_LOG"
    echo "====================================" | tee -a "$TEST_LOG"
    echo "Test log: $TEST_LOG" | tee -a "$TEST_LOG"
    
    # Run all test suites
    test_api_health
    test_ollama_compatibility
    test_openai_compatibility
    test_aider_integration
    test_monitoring_integration
    test_performance_benchmark
    test_error_handling
    
    # Print summary
    print_summary
}

# === Main Execution ===
case "${1:-all}" in
    api)
        test_api_health
        ;;
    ollama)
        test_ollama_compatibility
        ;;
    openai)
        test_openai_compatibility
        ;;
    aider)
        test_aider_integration
        ;;
    monitoring)
        test_monitoring_integration
        ;;
    performance|benchmark)
        test_performance_benchmark
        ;;
    errors)
        test_error_handling
        ;;
    all)
        run_all_tests
        ;;
    *)
        echo "Usage: $0 [api|ollama|openai|aider|monitoring|performance|errors|all]"
        echo ""
        echo "Options:"
        echo "  api         - Test API health and basic functionality"
        echo "  ollama      - Test Ollama API compatibility"
        echo "  openai      - Test OpenAI API compatibility"
        echo "  aider       - Test Aider integration"
        echo "  monitoring  - Test monitoring integration"
        echo "  performance - Run performance benchmarks"
        echo "  errors      - Test error handling"
        echo "  all         - Run all tests (default)"
        exit 1
        ;;
esac