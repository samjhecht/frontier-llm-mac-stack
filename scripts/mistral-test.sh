#!/bin/bash
# Frontier LLM Stack - Mistral.rs Integration Test Script
# 
# This script runs basic integration tests to verify Mistral.rs is working correctly.
#
# Usage:
#   ./mistral-test.sh

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
CONTAINER_NAME="frontier-mistral"
API_PORT="${MISTRAL_API_PORT:-8080}"
BASE_URL="http://localhost:${API_PORT}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

print_test() {
    echo -e "${YELLOW}TEST:${NC} $1"
}

print_pass() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    ((TESTS_FAILED++))
}

# Test 1: Container is running
print_test "Container is running"
if docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null | grep -q "true"; then
    print_pass "Container $CONTAINER_NAME is running"
else
    print_fail "Container $CONTAINER_NAME is not running"
    exit 1
fi

# Test 2: Health endpoint
print_test "Health endpoint"
if curl -sf "${BASE_URL}/health" >/dev/null; then
    print_pass "Health endpoint is responding"
else
    print_fail "Health endpoint is not responding"
fi

# Test 3: Models endpoint
print_test "Models endpoint"
MODELS_RESPONSE=$(curl -sf "${BASE_URL}/v1/models" 2>/dev/null || echo "FAILED")
if [ "$MODELS_RESPONSE" != "FAILED" ]; then
    print_pass "Models endpoint is responding"
    # Check if any models are loaded
    if echo "$MODELS_RESPONSE" | grep -q '"data"'; then
        echo "  Models found in response"
    else
        echo "  Warning: No models appear to be loaded"
    fi
else
    print_fail "Models endpoint is not responding"
fi

# Test 4: Chat completions endpoint (basic connectivity test)
print_test "Chat completions endpoint connectivity"
CHAT_RESPONSE=$(curl -sf -X POST "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d '{"messages":[{"role":"user","content":"test"}],"model":"test"}' 2>&1 || echo "FAILED")

if [[ "$CHAT_RESPONSE" == "FAILED" ]]; then
    print_fail "Chat completions endpoint is not responding"
elif echo "$CHAT_RESPONSE" | grep -q "model.*not.*found\|not.*loaded\|error"; then
    print_pass "Chat completions endpoint is responding (model not loaded is expected)"
else
    print_pass "Chat completions endpoint is responding"
fi

# Test 5: Monitoring metrics (if enabled)
print_test "Prometheus metrics endpoint"
if curl -sf "http://localhost:9090/api/v1/query?query=up" >/dev/null 2>&1; then
    print_pass "Prometheus is accessible"
else
    echo "  Prometheus not running (optional)"
fi

# Summary
echo ""
echo "Test Summary:"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed${NC}"
    exit 1
fi