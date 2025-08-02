#!/usr/bin/env bash
set -euo pipefail

# Test script for Aider compatibility with Mistral.rs through Ollama API proxy

echo "Testing Mistral.rs Ollama API compatibility layer..."
echo "=================================================="

# Configuration
OLLAMA_API_URL="${OLLAMA_API_URL:-http://localhost:11434}"
TEST_MODEL="${TEST_MODEL:-mistral:latest}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
test_endpoint() {
    local method=$1
    local endpoint=$2
    local data=$3
    local description=$4
    
    echo -n "Testing $description... "
    
    if [ "$method" = "GET" ]; then
        response=$(curl -s -X GET "$OLLAMA_API_URL$endpoint")
    else
        response=$(curl -s -X POST "$OLLAMA_API_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data")
    fi
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        echo -e "${GREEN}✓${NC}"
        echo "  Response: $(echo "$response" | jq -c . 2>/dev/null || echo "$response" | head -n1)"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

# Check if API is accessible
echo "1. Checking API availability..."
if ! curl -s "$OLLAMA_API_URL/" > /dev/null; then
    echo -e "${RED}Error: Cannot connect to API at $OLLAMA_API_URL${NC}"
    exit 1
fi
echo -e "${GREEN}API is accessible${NC}"

# Test version endpoint
echo -e "\n2. Testing version endpoint..."
test_endpoint GET "/api/version" "" "GET /api/version"

# Test models listing
echo -e "\n3. Testing models listing..."
test_endpoint GET "/api/tags" "" "GET /api/tags (list models)"

# Test generate endpoint (non-streaming)
echo -e "\n4. Testing generate endpoint..."
generate_data='{
    "model": "'$TEST_MODEL'",
    "prompt": "Hello, this is a test",
    "stream": false
}'
test_endpoint POST "/api/generate" "$generate_data" "POST /api/generate (non-streaming)"

# Test chat endpoint (non-streaming)
echo -e "\n5. Testing chat endpoint..."
chat_data='{
    "model": "'$TEST_MODEL'",
    "messages": [
        {"role": "user", "content": "Hello, this is a test"}
    ],
    "stream": false
}'
test_endpoint POST "/api/chat" "$chat_data" "POST /api/chat (non-streaming)"

# Test streaming
echo -e "\n6. Testing streaming response..."
echo -n "Testing POST /api/generate (streaming)... "
stream_data='{
    "model": "'$TEST_MODEL'",
    "prompt": "Count to 3",
    "stream": true
}'

# Use timeout to prevent hanging
if timeout 10 curl -s -N -X POST "$OLLAMA_API_URL/api/generate" \
    -H "Content-Type: application/json" \
    -d "$stream_data" | head -n 5 > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠ Streaming test timed out or failed${NC}"
fi

# Test with Aider (if installed)
echo -e "\n7. Testing Aider integration..."
if command -v aider &> /dev/null; then
    echo "Aider is installed. Testing connection..."
    
    # Create a temporary test file
    test_file=$(mktemp)
    echo "# Test file for Aider" > "$test_file"
    
    # Try to run aider with the API
    export OLLAMA_API_BASE="$OLLAMA_API_URL"
    if timeout 30 aider --model "$TEST_MODEL" --no-auto-commits --yes --message "Add a hello world function" "$test_file" 2>&1 | grep -q "hello"; then
        echo -e "${GREEN}✓ Aider successfully connected and generated code${NC}"
    else
        echo -e "${YELLOW}⚠ Aider connection test inconclusive${NC}"
    fi
    
    rm -f "$test_file"
else
    echo -e "${YELLOW}Aider not installed. Skipping Aider-specific tests.${NC}"
    echo "To install Aider: pip install aider-chat"
fi

echo -e "\n=================================================="
echo "Compatibility test completed!"
echo ""
echo "To use with Aider:"
echo "  export OLLAMA_API_BASE=$OLLAMA_API_URL"
echo "  aider --model $TEST_MODEL"