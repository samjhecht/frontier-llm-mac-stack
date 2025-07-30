# Step 10: Remote Connectivity Testing

## Overview
Comprehensively test the remote connectivity between MacBook Pro and Mac Studio, ensuring all services are accessible and performing well over the network.

## Tasks
1. Test all API endpoints from MacBook Pro
2. Measure network latency and throughput
3. Test concurrent connections
4. Verify streaming responses work correctly
5. Test failure scenarios and recovery

## Implementation Details

### 1. Comprehensive Connectivity Test Script
Create `scripts/testing/test-remote-connectivity.sh`:
```bash
#!/bin/bash
set -euo pipefail

# Get Mac Studio connection details
MAC_STUDIO_HOST="${1:-mac-studio.local}"
echo "Testing connectivity to: $MAC_STUDIO_HOST"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Test results array
declare -a test_results

# Function to run test and record result
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "Testing $test_name... "
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        test_results+=("✓ $test_name")
        return 0
    else
        echo -e "${RED}✗${NC}"
        test_results+=("✗ $test_name")
        return 1
    fi
}

# 1. Basic connectivity
run_test "SSH connectivity" "ssh -o ConnectTimeout=5 $MAC_STUDIO_HOST 'echo connected'"
run_test "Ping response" "ping -c 3 -W 2 $MAC_STUDIO_HOST"

# 2. Service endpoints
run_test "Ollama API" "curl -s --connect-timeout 5 http://$MAC_STUDIO_HOST:11434/api/version"
run_test "Grafana UI" "curl -s --connect-timeout 5 http://$MAC_STUDIO_HOST:3000/api/health"
run_test "Prometheus" "curl -s --connect-timeout 5 http://$MAC_STUDIO_HOST:9090/-/ready"
run_test "Nginx proxy" "curl -s --connect-timeout 5 http://$MAC_STUDIO_HOST/health"

# 3. Ollama functionality
run_test "Model listing" "curl -s http://$MAC_STUDIO_HOST:11434/api/tags | jq -e '.models | length > 0'"

# 4. Network performance
echo -e "\n=== Network Performance ==="
# Latency test
avg_latency=$(ping -c 10 $MAC_STUDIO_HOST | tail -1 | awk -F '/' '{print $5}')
echo "Average latency: ${avg_latency}ms"

# Throughput test (small file)
echo "Testing throughput..."
dd if=/dev/zero bs=1M count=10 2>/dev/null | \
    ssh $MAC_STUDIO_HOST "cat > /dev/null" 2>&1 | \
    grep -o "[0-9.]* MB/s" || echo "Throughput test failed"
```

### 2. Streaming Response Test
Create `scripts/testing/test-streaming.sh`:
```bash
#!/bin/bash
# Test streaming responses from Ollama

MAC_STUDIO_HOST="${1:-mac-studio.local}"

echo "Testing streaming response..."
curl -X POST "http://$MAC_STUDIO_HOST:11434/api/generate" \
    -H "Content-Type: application/json" \
    -d '{
        "model": "qwen2.5-coder:32b-instruct-q8_0",
        "prompt": "Write a Python web server in FastAPI with user authentication",
        "stream": true
    }' \
    --no-buffer | while IFS= read -r line; do
        echo "$line" | jq -r '.response' 2>/dev/null || true
    done
```

### 3. Load Testing
Create `scripts/testing/test-concurrent-load.sh`:
```bash
#!/bin/bash
# Test concurrent connections

MAC_STUDIO_HOST="${1:-mac-studio.local}"
CONCURRENT_REQUESTS=5

echo "Testing $CONCURRENT_REQUESTS concurrent requests..."

# Function to make request
make_request() {
    local id=$1
    local start=$(date +%s.%N)
    
    curl -s -X POST "http://$MAC_STUDIO_HOST:11434/api/generate" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"qwen2.5-coder:32b-instruct-q8_0\",
            \"prompt\": \"Hello from request $id\",
            \"stream\": false,
            \"options\": {\"num_predict\": 50}
        }" > /dev/null
    
    local end=$(date +%s.%N)
    local duration=$(echo "$end - $start" | bc)
    echo "Request $id completed in ${duration}s"
}

# Launch concurrent requests
for i in $(seq 1 $CONCURRENT_REQUESTS); do
    make_request $i &
done

# Wait for all to complete
wait
echo "All requests completed"
```

### 4. Failure Recovery Test
```bash
# Test service recovery
echo "Testing service recovery..."

# Stop Ollama on Mac Studio
ssh $MAC_STUDIO_HOST "cd ~/frontier-llm-mac-stack && docker compose stop ollama"

# Try request (should fail)
if ! curl -s --connect-timeout 5 http://$MAC_STUDIO_HOST:11434/api/version; then
    echo "Service correctly unavailable"
fi

# Restart service
ssh $MAC_STUDIO_HOST "cd ~/frontier-llm-mac-stack && docker compose start ollama"

# Wait for recovery
sleep 10

# Verify recovery
if curl -s http://$MAC_STUDIO_HOST:11434/api/version; then
    echo "Service recovered successfully"
fi
```

## Dependencies
- All previous steps completed
- Network connectivity between machines
- Services running on Mac Studio

## Success Criteria
- All connectivity tests pass
- Network latency < 5ms on LAN
- Streaming responses work smoothly
- Concurrent requests handled properly
- Services recover from failures

## Testing
Run the comprehensive test suite:
```bash
./scripts/testing/test-remote-connectivity.sh mac-studio.local
./scripts/testing/test-streaming.sh mac-studio.local
./scripts/testing/test-concurrent-load.sh mac-studio.local
```

## Notes
- Consider setting up monitoring alerts for connectivity issues
- Network performance may vary with model size and complexity
- SSH ControlMaster improves performance for multiple connections