#!/bin/bash
set -e

echo "Testing Mistral.rs Monitoring Integration"
echo "========================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check endpoint
check_endpoint() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}
    
    echo -n "Checking $name... "
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" || echo "000")
    
    if [ "$response" = "$expected_code" ]; then
        echo -e "${GREEN}✓${NC} (HTTP $response)"
        return 0
    else
        echo -e "${RED}✗${NC} (HTTP $response, expected $expected_code)"
        return 1
    fi
}

# Function to check metrics
check_metrics() {
    local service=$1
    local url=$2
    local metric=$3
    
    echo -n "Checking $service metrics for '$metric'... "
    
    metrics=$(curl -s "$url" || echo "")
    
    if echo "$metrics" | grep -q "$metric"; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

echo "1. Checking Prometheus endpoints"
echo "--------------------------------"
check_endpoint "Prometheus UI" "http://localhost:9090"
check_endpoint "Prometheus targets" "http://localhost:9090/api/v1/targets"

echo ""
echo "2. Checking Mistral.rs metrics endpoint"
echo "---------------------------------------"
# Note: This assumes the proxy is running on port 11434
check_endpoint "Mistral metrics" "http://localhost:11434/metrics"
check_endpoint "Mistral API metrics" "http://localhost:11434/api/metrics"

echo ""
echo "3. Checking for specific metrics"
echo "--------------------------------"
check_metrics "Mistral" "http://localhost:11434/metrics" "mistral_http_requests_total"
check_metrics "Mistral" "http://localhost:11434/metrics" "mistral_http_request_duration_seconds"
check_metrics "Mistral" "http://localhost:11434/metrics" "mistral_active_requests"
check_metrics "Mistral" "http://localhost:11434/metrics" "mistral_streaming_chunks_total"

echo ""
echo "4. Checking Prometheus scraping"
echo "-------------------------------"
echo -n "Checking if Prometheus is scraping Mistral... "

targets=$(curl -s "http://localhost:9090/api/v1/targets" || echo "{}")
if echo "$targets" | grep -q "mistral.*up"; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠${NC} (May not be up yet)"
fi

echo ""
echo "5. Checking Grafana"
echo "-------------------"
check_endpoint "Grafana UI" "http://localhost:3000"

echo ""
echo "6. Checking alerting rules"
echo "-------------------------"
echo -n "Checking if alerting rules are loaded... "

rules=$(curl -s "http://localhost:9090/api/v1/rules" || echo "{}")
if echo "$rules" | grep -q "mistral_alerts"; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠${NC} (Rules may not be loaded yet)"
fi

echo ""
echo "7. Generating test traffic"
echo "-------------------------"
echo "Sending test requests to generate metrics..."

# Send a few test requests
for i in {1..5}; do
    echo -n "Request $i: "
    response=$(curl -s -X POST http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d '{
            "model": "mistral-7b",
            "prompt": "Hello, world!",
            "stream": false
        }' -o /dev/null -w "%{http_code}" || echo "000")
    
    if [ "$response" = "200" ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC} (HTTP $response)"
    fi
    
    sleep 1
done

echo ""
echo "Test Summary"
echo "============"
echo "Check the following:"
echo "1. Prometheus targets: http://localhost:9090/targets"
echo "2. Mistral metrics: http://localhost:11434/metrics"
echo "3. Grafana dashboard: http://localhost:3000 (login: admin/changeme)"
echo "4. Look for 'Mistral.rs Metrics' dashboard in Grafana"
echo ""
echo "Note: It may take a few minutes for all metrics to appear in Prometheus and Grafana."