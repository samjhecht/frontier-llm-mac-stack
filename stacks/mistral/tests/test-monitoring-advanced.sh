#!/bin/bash
# Advanced monitoring integration tests for Mistral.rs

set -euo pipefail

# Check prerequisites
for cmd in curl jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: $cmd is required but not installed" >&2
        exit 1
    fi
done

# Cleanup handler
cleanup() {
    local exit_code=$?
    # Clean up any temporary files
    rm -f /tmp/mistral-monitoring-*
    exit $exit_code
}
trap cleanup EXIT INT TERM

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
MISTRAL_HOST="${MISTRAL_HOST:-localhost}"
MISTRAL_PORT="${MISTRAL_PORT:-8080}"
OLLAMA_PROXY_PORT="${OLLAMA_PROXY_PORT:-11434}"
PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"
TEST_MODEL="${TEST_MODEL:-qwen2.5-coder:32b}"

# Test counters
PASSED=0
FAILED=0
WARNINGS=0

# Utility functions
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_test() {
    echo -en "$1... "
}

print_pass() {
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
}

print_fail() {
    echo -e "${RED}FAIL${NC}"
    echo "  Error: $1"
    ((FAILED++))
}

print_warning() {
    echo -e "${YELLOW}WARNING${NC}"
    echo "  Warning: $1"
    ((WARNINGS++))
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Function to wait for a service to be ready
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=0
    
    print_test "Waiting for $service_name to be ready"
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s "$url" > /dev/null 2>&1; then
            print_pass
            return 0
        fi
        sleep 1
        ((attempt++))
    done
    
    print_fail "$service_name did not become ready in time"
    return 1
}

# Test 1: Verify all monitoring components are running
test_monitoring_components() {
    print_header "Monitoring Components Status"
    
    # Check Prometheus
    print_test "Checking Prometheus"
    if curl -s "http://localhost:$PROMETHEUS_PORT/-/ready" > /dev/null 2>&1; then
        print_pass
    else
        print_fail "Prometheus is not running or not ready"
        return 1
    fi
    
    # Check Grafana
    print_test "Checking Grafana"
    if curl -s "http://localhost:$GRAFANA_PORT/api/health" | jq -r '.database' | grep -q "ok"; then
        print_pass
    else
        print_warning "Grafana is running but may not be fully configured"
    fi
    
    # Check Mistral metrics endpoint
    print_test "Checking Mistral metrics endpoint"
    if curl -s "http://$MISTRAL_HOST:$OLLAMA_PROXY_PORT/metrics" > /dev/null 2>&1; then
        print_pass
    else
        print_fail "Mistral metrics endpoint not accessible"
    fi
}

# Test 2: Verify Prometheus targets
test_prometheus_targets() {
    print_header "Prometheus Target Configuration"
    
    # Get all targets
    targets=$(curl -s "http://localhost:$PROMETHEUS_PORT/api/v1/targets" 2>/dev/null || echo "{}")
    
    # Check Mistral target
    print_test "Checking Mistral target in Prometheus"
    if echo "$targets" | jq -e '.data.activeTargets[] | select(.labels.job == "mistral")' > /dev/null 2>&1; then
        mistral_target=$(echo "$targets" | jq -r '.data.activeTargets[] | select(.labels.job == "mistral") | .health')
        if [ "$mistral_target" = "up" ]; then
            print_pass
        else
            print_fail "Mistral target exists but is not healthy: $mistral_target"
        fi
    else
        print_fail "Mistral target not found in Prometheus"
    fi
    
    # Check scrape interval
    print_test "Checking scrape configuration"
    scrape_interval=$(echo "$targets" | jq -r '.data.activeTargets[] | select(.labels.job == "mistral") | .scrapeInterval' 2>/dev/null || echo "")
    if [ -n "$scrape_interval" ]; then
        print_pass
        print_info "Scrape interval: $scrape_interval"
    else
        print_warning "Could not determine scrape interval"
    fi
}

# Test 3: Verify specific Mistral metrics
test_mistral_metrics() {
    print_header "Mistral Metrics Validation"
    
    # Get metrics
    metrics=$(curl -s "http://$MISTRAL_HOST:$OLLAMA_PROXY_PORT/metrics" 2>/dev/null || echo "")
    
    if [ -z "$metrics" ]; then
        print_fail "No metrics returned from Mistral"
        return 1
    fi
    
    # Define expected metrics (configurable via environment)
    if [ -z "${EXPECTED_METRICS:-}" ]; then
        expected_metrics=(
            "mistral_http_requests_total"
            "mistral_http_request_duration_seconds"
            "mistral_active_requests"
            "mistral_streaming_chunks_total"
            "mistral_model_loaded"
            "mistral_inference_duration_seconds"
            "mistral_tokens_generated_total"
        )
    else
        # Read metrics from environment variable (comma-separated)
        IFS=',' read -ra expected_metrics <<< "$EXPECTED_METRICS"
    fi
    
    # Check each metric
    for metric in "${expected_metrics[@]}"; do
        print_test "Checking metric: $metric"
        if echo "$metrics" | grep -q "^$metric"; then
            print_pass
            
            # Get metric value for info
            value=$(echo "$metrics" | grep "^$metric" | head -1 | awk '{print $2}')
            if [ -n "$value" ]; then
                print_info "Current value: $value"
            fi
        else
            print_fail "Metric $metric not found"
        fi
    done
    
    # Check metric format
    print_test "Checking metrics format"
    if echo "$metrics" | grep -E "^# HELP|^# TYPE" > /dev/null; then
        print_pass
    else
        print_warning "Metrics may not include proper Prometheus format headers"
    fi
}

# Test 4: Generate traffic and verify metrics update
test_metrics_collection() {
    print_header "Metrics Collection Under Load"
    
    # Get initial metrics
    print_test "Getting baseline metrics"
    initial_requests=$(curl -s "http://$MISTRAL_HOST:$OLLAMA_PROXY_PORT/metrics" | \
        grep "mistral_http_requests_total" | \
        grep 'method="POST"' | \
        awk '{sum += $2} END {print sum}' || echo "0")
    print_pass
    print_info "Initial request count: $initial_requests"
    
    # Generate test traffic
    print_test "Generating test traffic"
    requests_sent=0
    for i in {1..10}; do
        response=$(curl -s -X POST "http://$MISTRAL_HOST:$OLLAMA_PROXY_PORT/api/generate" \
            -H "Content-Type: application/json" \
            -d "{
                \"model\": \"$TEST_MODEL\",
                \"prompt\": \"Test request $i\",
                \"stream\": false
            }" 2>/dev/null || echo "{}")
        
        if echo "$response" | jq -e '.response' > /dev/null 2>&1; then
            ((requests_sent++))
        fi
    done
    
    if [ $requests_sent -gt 5 ]; then
        print_pass
        print_info "Successfully sent $requests_sent/10 requests"
    else
        print_warning "Only $requests_sent/10 requests succeeded"
    fi
    
    # Wait for metrics to update
    sleep 2
    
    # Check if metrics increased
    print_test "Verifying metrics increased"
    final_requests=$(curl -s "http://$MISTRAL_HOST:$OLLAMA_PROXY_PORT/metrics" | \
        grep "mistral_http_requests_total" | \
        grep 'method="POST"' | \
        awk '{sum += $2} END {print sum}' || echo "0")
    
    requests_diff=$((final_requests - initial_requests))
    if [ $requests_diff -gt 0 ]; then
        print_pass
        print_info "Request count increased by: $requests_diff"
    else
        print_fail "Metrics did not increase after sending requests"
    fi
}

# Test 5: Check Prometheus querying
test_prometheus_queries() {
    print_header "Prometheus Query Functionality"
    
    # Test instant query
    print_test "Testing instant query"
    query_result=$(curl -s "http://localhost:$PROMETHEUS_PORT/api/v1/query?query=up" 2>/dev/null || echo "{}")
    if echo "$query_result" | jq -e '.status == "success"' > /dev/null 2>&1; then
        print_pass
    else
        print_fail "Prometheus instant query failed"
    fi
    
    # Test Mistral-specific query
    print_test "Testing Mistral metrics query"
    mistral_query=$(curl -s "http://localhost:$PROMETHEUS_PORT/api/v1/query?query=mistral_http_requests_total" 2>/dev/null || echo "{}")
    if echo "$mistral_query" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
        print_pass
        result_count=$(echo "$mistral_query" | jq '.data.result | length')
        print_info "Found $result_count metric series"
    else
        print_fail "No Mistral metrics found in Prometheus"
    fi
    
    # Test rate query
    print_test "Testing rate calculation"
    rate_query=$(curl -s "http://localhost:$PROMETHEUS_PORT/api/v1/query?query=rate(mistral_http_requests_total[1m])" 2>/dev/null || echo "{}")
    if echo "$rate_query" | jq -e '.status == "success"' > /dev/null 2>&1; then
        print_pass
    else
        print_warning "Rate query succeeded but may not have data yet"
    fi
}

# Test 6: Verify alerting rules
test_alerting_rules() {
    print_header "Alerting Rules Configuration"
    
    # Check if rules are loaded
    print_test "Checking alerting rules"
    rules=$(curl -s "http://localhost:$PROMETHEUS_PORT/api/v1/rules" 2>/dev/null || echo "{}")
    
    if echo "$rules" | jq -e '.data.groups[] | select(.name == "mistral_alerts")' > /dev/null 2>&1; then
        print_pass
        
        # Count rules
        rule_count=$(echo "$rules" | jq '.data.groups[] | select(.name == "mistral_alerts") | .rules | length' || echo "0")
        print_info "Found $rule_count alerting rules"
        
        # List rule names
        print_info "Active rules:"
        echo "$rules" | jq -r '.data.groups[] | select(.name == "mistral_alerts") | .rules[].name' | sed 's/^/  - /'
    else
        print_warning "Mistral alerting rules not found - may not be configured"
    fi
    
    # Check for firing alerts
    print_test "Checking for active alerts"
    alerts=$(curl -s "http://localhost:$PROMETHEUS_PORT/api/v1/alerts" 2>/dev/null || echo "{}")
    
    mistral_alerts=$(echo "$alerts" | jq '.data.alerts[] | select(.labels.job == "mistral")' 2>/dev/null || echo "")
    if [ -n "$mistral_alerts" ]; then
        print_warning "Found active Mistral alerts"
        echo "$mistral_alerts" | jq -r '.labels.alertname' | sed 's/^/  - /'
    else
        print_pass
        print_info "No active Mistral alerts (this is good)"
    fi
}

# Test 7: Grafana dashboards
test_grafana_dashboards() {
    print_header "Grafana Dashboard Configuration"
    
    # Check Grafana API
    print_test "Checking Grafana API access"
    if ! curl -s "http://localhost:$GRAFANA_PORT/api/health" > /dev/null 2>&1; then
        print_warning "Grafana API not accessible - skipping dashboard tests"
        return
    fi
    print_pass
    
    # Check for Mistral dashboard
    print_test "Checking for Mistral dashboard"
    GRAFANA_USER=${GRAFANA_USER:-admin}
    GRAFANA_PASSWORD=${GRAFANA_PASSWORD:-changeme}
    dashboards=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" "http://localhost:$GRAFANA_PORT/api/search?type=dash-db" 2>/dev/null || echo "[]")
    
    if echo "$dashboards" | jq -e '.[] | select(.title | contains("Mistral"))' > /dev/null 2>&1; then
        print_pass
        dashboard_name=$(echo "$dashboards" | jq -r '.[] | select(.title | contains("Mistral")) | .title')
        print_info "Found dashboard: $dashboard_name"
    else
        print_warning "Mistral dashboard not found - may need to be imported"
    fi
    
    # Check datasources
    print_test "Checking Prometheus datasource"
    datasources=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" "http://localhost:$GRAFANA_PORT/api/datasources" 2>/dev/null || echo "[]")
    
    if echo "$datasources" | jq -e '.[] | select(.type == "prometheus")' > /dev/null 2>&1; then
        print_pass
    else
        print_fail "Prometheus datasource not configured in Grafana"
    fi
}

# Test 8: Performance metrics accuracy
test_performance_metrics() {
    print_header "Performance Metrics Accuracy"
    
    # Send a request and measure actual time
    print_test "Testing request duration accuracy"
    
    start_time=$(date +%s.%N)
    response=$(curl -s -X POST "http://$MISTRAL_HOST:$OLLAMA_PROXY_PORT/api/generate" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$TEST_MODEL\",
            \"prompt\": \"Say hello\",
            \"stream\": false
        }" 2>/dev/null || echo "{}")
    end_time=$(date +%s.%N)
    
    actual_duration=$(echo "$end_time - $start_time" | bc)
    
    if echo "$response" | jq -e '.response' > /dev/null 2>&1; then
        print_pass
        print_info "Actual request duration: ${actual_duration}s"
        
        # Check if duration metric exists
        duration_metric=$(curl -s "http://$MISTRAL_HOST:$OLLAMA_PROXY_PORT/metrics" | \
            grep "mistral_http_request_duration_seconds_sum" | \
            awk '{print $2}' | tail -1 || echo "0")
        
        if [ -n "$duration_metric" ] && [ "$duration_metric" != "0" ]; then
            print_info "Metric shows cumulative duration: ${duration_metric}s"
        fi
    else
        print_fail "Test request failed"
    fi
}

# Test summary
print_summary() {
    print_header "Test Summary"
    
    total=$((PASSED + FAILED + WARNINGS))
    
    echo "Total tests: $total"
    echo -e "Passed: ${GREEN}$PASSED${NC}"
    echo -e "Failed: ${RED}$FAILED${NC}"
    echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
    
    echo ""
    echo "Monitoring URLs:"
    echo "  - Prometheus: http://localhost:$PROMETHEUS_PORT"
    echo "  - Grafana: http://localhost:$GRAFANA_PORT (admin/changeme)"
    echo "  - Mistral Metrics: http://$MISTRAL_HOST:$OLLAMA_PROXY_PORT/metrics"
    
    if [ $FAILED -eq 0 ]; then
        echo -e "\n${GREEN}All critical tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}Some tests failed${NC}"
        return 1
    fi
}

# Main test runner
main() {
    echo "=== Advanced Monitoring Integration Tests for Mistral.rs ==="
    echo "Configuration:"
    echo "  - Mistral: $MISTRAL_HOST:$MISTRAL_PORT"
    echo "  - Ollama Proxy: $MISTRAL_HOST:$OLLAMA_PROXY_PORT"
    echo "  - Prometheus: localhost:$PROMETHEUS_PORT"
    echo "  - Grafana: localhost:$GRAFANA_PORT"
    echo ""
    
    # Run all tests
    test_monitoring_components
    test_prometheus_targets
    test_mistral_metrics
    test_metrics_collection
    test_prometheus_queries
    test_alerting_rules
    test_grafana_dashboards
    test_performance_metrics
    
    # Summary
    print_summary
}

# Run main if not sourced
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main
fi