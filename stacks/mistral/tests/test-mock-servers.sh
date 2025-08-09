#!/bin/bash
# Simple test script for mock servers

set -e

echo "Testing Mock Servers"
echo "==================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASSED=0
FAILED=0

test_endpoint() {
    local url="$1"
    local expected="$2"
    local description="$3"
    
    echo -n "Testing $description... "
    
    response=$(curl -s "$url" 2>/dev/null || echo "FAILED")
    
    if [[ "$response" == *"$expected"* ]]; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Expected: $expected"
        echo "  Got: ${response:0:100}"
        ((FAILED++))
    fi
}

# Test port 8080 endpoints
echo -e "\nPort 8080 (Mistral API):"
test_endpoint "http://localhost:8080/health" "OK" "Health endpoint"
test_endpoint "http://localhost:8080/v1/models" "qwen2.5-coder:32b" "Models endpoint"

# Test port 11434 endpoints  
echo -e "\nPort 11434 (Ollama API):"
test_endpoint "http://localhost:11434/" "Mistral.rs" "Root endpoint"
test_endpoint "http://localhost:11434/api/tags" "qwen2.5-coder:32b" "Tags endpoint"
test_endpoint "http://localhost:11434/api/version" "0.1.0" "Version endpoint"

# Test chat completion
echo -e "\nChat Completion Test:"
response=$(curl -s -X POST http://localhost:8080/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "qwen2.5-coder:32b",
        "messages": [{"role": "user", "content": "test"}],
        "max_tokens": 10
    }' 2>/dev/null | jq -r '.choices[0].message.content' 2>/dev/null || echo "FAILED")

if [[ "$response" == "This is a mock response"* ]]; then
    echo -e "Chat completion... ${GREEN}PASS${NC}"
    ((PASSED++))
else
    echo -e "Chat completion... ${RED}FAIL${NC}"
    echo "  Response: $response"
    ((FAILED++))
fi

# Summary
echo -e "\n==================="
echo "Test Summary:"
echo -e "  Passed: ${GREEN}$PASSED${NC}"
echo -e "  Failed: ${RED}$FAILED${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed${NC}"
    exit 1
fi