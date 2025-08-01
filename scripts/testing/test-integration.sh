#!/bin/bash
set -euo pipefail

# test-integration.sh - Integration testing for the entire LLM stack
# Tests all components working together

echo "=== Frontier LLM Stack Integration Tests ==="

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
PASSED=0
FAILED=0
SKIPPED=0

# Configuration
OLLAMA_HOST="${OLLAMA_HOST:-localhost}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"
PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"

# Function to print colored output
print_test_header() { echo -e "\n${BLUE}TEST: $1${NC}"; }
print_pass() { echo -e "${GREEN}✓ PASS${NC}: $1"; PASSED=$((PASSED + 1)); }
print_fail() { echo -e "${RED}✗ FAIL${NC}: $1"; FAILED=$((FAILED + 1)); }
print_skip() { echo -e "${YELLOW}⚠ SKIP${NC}: $1"; SKIPPED=$((SKIPPED + 1)); }
print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

# Test Docker installation
test_docker() {
    print_test_header "Docker Installation"
    
    if command -v docker &> /dev/null; then
        print_pass "Docker is installed"
    else
        print_fail "Docker is not installed"
        return 1
    fi
    
    if docker info &> /dev/null; then
        print_pass "Docker daemon is running"
    else
        print_fail "Docker daemon is not running"
        return 1
    fi
    
    return 0
}

# Test Ollama service
test_ollama() {
    print_test_header "Ollama Service"
    
    # Check if Ollama image is being downloaded
    if docker images | grep -q "ollama/ollama.*<none>"; then
        print_skip "Ollama image is still downloading"
        print_info "Run tests again after image download completes"
        return 0
    fi
    
    # Check if Ollama container exists
    if ! docker ps -a | grep -q "ollama"; then
        print_skip "Ollama container not found - services may not be started"
        print_info "Run './start.sh' to start services"
        return 0
    fi
    
    if curl -s --max-time 5 "http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/version" > /dev/null 2>&1; then
        print_pass "Ollama API is accessible"
        
        # Get version
        version=$(curl -s --max-time 5 "http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/version" | jq -r '.version' 2>/dev/null || echo "unknown")
        print_info "Ollama version: $version"
    else
        print_fail "Cannot connect to Ollama API"
        return 1
    fi
    
    # Check for models
    models=$(curl -s --max-time 5 "http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/tags" 2>/dev/null | jq -r '.models[]?.name' 2>/dev/null || true)
    if [[ -n "$models" ]]; then
        print_pass "Models are available"
        echo "$models" | sed 's/^/  - /'
    else
        print_fail "No models found"
        print_info "Run './pull-model.sh' to download a model"
        return 1
    fi
}

# Test model response
test_model_response() {
    print_test_header "Model Response"
    
    # Get first available model
    model=$(curl -s --max-time 5 "http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/tags" 2>/dev/null | jq -r '.models[0].name' 2>/dev/null || true)
    
    if [[ -z "$model" ]]; then
        print_skip "No model available for testing"
        return 0
    fi
    
    print_info "Testing model: $model"
    
    # Test simple prompt
    response=$(curl -s --max-time 10 -X POST "http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/generate" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "'"$model"'",
            "prompt": "Say hello",
            "stream": false
        }' 2>/dev/null)
    
    if [[ -n "$response" ]] && echo "$response" | jq -e '.response' > /dev/null 2>&1; then
        print_pass "Model responds to prompts"
        response_text=$(echo "$response" | jq -r '.response' | head -c 100)
        print_info "Response preview: ${response_text}..."
    else
        print_fail "Model did not respond correctly"
        return 1
    fi
}

# Test Prometheus
test_prometheus() {
    print_test_header "Prometheus Monitoring"
    
    if curl -s --max-time 5 "http://localhost:${PROMETHEUS_PORT}/-/ready" > /dev/null 2>&1; then
        print_pass "Prometheus is running"
    else
        print_skip "Prometheus is not accessible"
        return 0
    fi
    
    # Check targets
    targets=$(curl -s --max-time 5 "http://localhost:${PROMETHEUS_PORT}/api/v1/targets" 2>/dev/null | jq -r '.data.activeTargets[]?.health' 2>/dev/null || true)
    if [[ -n "$targets" ]]; then
        print_pass "Prometheus has active targets"
    else
        print_fail "No active Prometheus targets"
    fi
}

# Test Grafana
test_grafana() {
    print_test_header "Grafana Dashboard"
    
    if curl -s --max-time 5 "http://localhost:${GRAFANA_PORT}/api/health" > /dev/null 2>&1; then
        print_pass "Grafana is running"
        print_info "Access dashboard at: http://localhost:${GRAFANA_PORT}"
    else
        print_skip "Grafana is not accessible"
        return 0
    fi
}

# Test Aider installation
test_aider() {
    print_test_header "Aider Installation"
    
    if command -v aider &> /dev/null; then
        print_pass "Aider is installed"
        echo "  Aider is available"
    else
        print_skip "Aider is not installed"
        print_info "Run './scripts/setup/05-install-aider.sh' to install"
        return 0
    fi
    
    # Check Aider config
    if [[ -f ~/.aider.conf.yml ]]; then
        print_pass "Aider configuration found"
    else
        print_fail "Aider configuration not found"
    fi
}

# Test Aider + Ollama integration
test_aider_ollama() {
    print_test_header "Aider + Ollama Integration"
    
    if ! command -v aider &> /dev/null; then
        print_skip "Aider not installed"
        return 0
    fi
    
    # Create temporary test directory
    test_dir=$(mktemp -d)
    cd "$test_dir"
    git init > /dev/null 2>&1
    
    # Create test file
    cat > test.py << 'EOF'
def add(a, b):
    # TODO: implement addition
    pass
EOF
    
    # Test Aider with Ollama
    export OLLAMA_API_BASE="http://${OLLAMA_HOST}:${OLLAMA_PORT}"
    
    # Get first available model
    model=$(curl -s --max-time 5 "${OLLAMA_API_BASE}/api/tags" 2>/dev/null | jq -r '.models[0].name' 2>/dev/null || true)
    
    if [[ -z "$model" ]]; then
        print_skip "No model available for Aider test"
        cd - > /dev/null
        rm -rf "$test_dir"
        return 0
    fi
    
    # Try to run Aider (non-interactive test)
    if echo "implement the add function" | timeout 30 aider --model "ollama/${model}" --yes --no-auto-commits test.py 2>/dev/null; then
        if grep -q "return a + b" test.py; then
            print_pass "Aider successfully modified code using Ollama"
        else
            print_fail "Aider ran but did not modify code as expected"
        fi
    else
        print_fail "Aider failed to run with Ollama"
    fi
    
    cd - > /dev/null
    rm -rf "$test_dir"
}

# Test network connectivity
test_network() {
    print_test_header "Network Configuration"
    
    # Test local connectivity
    if ping -c 1 -W 1 localhost &> /dev/null; then
        print_pass "Local network connectivity"
    else
        print_fail "Local network issue"
    fi
    
    # Test if mac-studio.local is resolvable
    if ping -c 1 -W 1 mac-studio.local &> /dev/null 2>&1; then
        print_pass "mac-studio.local is reachable"
    else
        print_skip "mac-studio.local not configured"
    fi
}

# Test file permissions
test_permissions() {
    print_test_header "File Permissions"
    
    # Check script permissions
    scripts=(
        "scripts/setup/docker-setup.sh"
        "start.sh"
        "stop.sh"
        "pull-model.sh"
    )
    
    all_executable=true
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]] && [[ -x "$script" ]]; then
            print_pass "$script is executable"
        elif [[ -f "$script" ]]; then
            print_fail "$script is not executable"
            all_executable=false
        fi
    done
    
    if [[ "$all_executable" == true ]]; then
        print_pass "All scripts have correct permissions"
    fi
}

# Performance check
test_performance() {
    print_test_header "Performance Check"
    
    # Check available memory
    if [[ "$(uname)" == "Darwin" ]]; then
        total_memory=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
        print_info "Total system memory: ${total_memory}GB"
        
        if [[ $total_memory -ge 32 ]]; then
            print_pass "Sufficient memory for large models"
        else
            print_fail "Limited memory - large models may not run well"
        fi
    fi
    
    # Check disk space
    available_space=$(df -g . | awk 'NR==2 {print $4}')
    print_info "Available disk space: ${available_space}GB"
    
    if [[ $available_space -ge 100 ]]; then
        print_pass "Sufficient disk space"
    else
        print_fail "Low disk space - may limit model storage"
    fi
}

# Run all tests
run_all_tests() {
    print_info "Starting integration tests..."
    
    # Core tests
    test_docker
    test_network
    test_permissions
    
    # Service tests
    test_ollama
    test_model_response
    test_prometheus
    test_grafana
    
    # Integration tests
    test_aider
    test_aider_ollama
    
    # System tests
    test_performance
    
    # Summary
    echo
    echo "========================================"
    echo "Test Summary:"
    echo "  Passed:  $PASSED"
    echo "  Failed:  $FAILED"
    echo "  Skipped: $SKIPPED"
    echo "========================================"
    
    if [[ $FAILED -gt 0 ]]; then
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    else
        echo -e "${GREEN}All critical tests passed!${NC}"
        return 0
    fi
}

# Main execution
case "${1:-}" in
    docker)
        test_docker
        ;;
    ollama)
        test_ollama
        test_model_response
        ;;
    monitoring)
        test_prometheus
        test_grafana
        ;;
    aider)
        test_aider
        test_aider_ollama
        ;;
    quick)
        test_docker
        test_ollama
        ;;
    *)
        run_all_tests
        ;;
esac