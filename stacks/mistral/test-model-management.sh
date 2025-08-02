#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Test function
run_test() {
    local name="$1"
    local command="$2"
    local expected_exit="${3:-0}"
    
    print_test "$name"
    
    set +e
    output=$(eval "$command" 2>&1)
    exit_code=$?
    set -e
    
    if [ $exit_code -eq $expected_exit ]; then
        print_pass "$name"
        return 0
    else
        print_fail "$name (exit code: $exit_code, expected: $expected_exit)"
        echo "Output: $output"
        return 1
    fi
}

# Main tests
echo "=== Mistral Model Management Test Suite ==="
echo ""

# Test 1: Check scripts exist and are executable
print_info "Testing script availability..."
for script in pull-model.sh convert-model.sh list-models.sh delete-model.sh check-disk-space.sh configure-model.sh; do
    if [ -x "${SCRIPTS_DIR}/${script}" ]; then
        print_pass "Script exists and is executable: $script"
    else
        print_fail "Script missing or not executable: $script"
    fi
done

echo ""

# Test 2: Test help commands
print_info "Testing help commands..."
run_test "pull-model.sh help" "${SCRIPTS_DIR}/pull-model.sh help"
run_test "convert-model.sh help" "${SCRIPTS_DIR}/convert-model.sh help"
run_test "list-models.sh help" "${SCRIPTS_DIR}/list-models.sh help"
run_test "delete-model.sh help" "${SCRIPTS_DIR}/delete-model.sh help"
run_test "check-disk-space.sh help" "${SCRIPTS_DIR}/check-disk-space.sh help"
run_test "configure-model.sh help" "${SCRIPTS_DIR}/configure-model.sh help"

echo ""

# Test 3: Test listing functions
print_info "Testing listing functions..."
run_test "List available models" "${SCRIPTS_DIR}/pull-model.sh list"
run_test "List local models (detailed)" "${SCRIPTS_DIR}/list-models.sh detailed"
run_test "List local models (simple)" "${SCRIPTS_DIR}/list-models.sh simple"
run_test "List local models (json)" "${SCRIPTS_DIR}/list-models.sh json"
run_test "List model configurations" "${SCRIPTS_DIR}/configure-model.sh list"

echo ""

# Test 4: Test disk space check
print_info "Testing disk space check..."
run_test "Check disk space (default)" "${SCRIPTS_DIR}/check-disk-space.sh"
run_test "Check disk space (20GB)" "${SCRIPTS_DIR}/check-disk-space.sh 20"

echo ""

# Test 5: Test error handling
print_info "Testing error handling..."
run_test "Invalid model pull" "${SCRIPTS_DIR}/pull-model.sh nonexistent-model" 1
run_test "Invalid quantization" "${SCRIPTS_DIR}/convert-model.sh /tmp/fake.gguf gguf invalid_quant" 1
run_test "Delete without model name" "${SCRIPTS_DIR}/delete-model.sh" 1

echo ""

# Test 6: Check configuration files
print_info "Testing configuration files..."
for config in model-template.toml mistral-7b.toml qwen2.5-coder-32b.toml mixtral-8x7b.toml lora-adapter-template.toml; do
    if [ -f "${SCRIPT_DIR}/config/models/${config}" ]; then
        print_pass "Configuration exists: $config"
    else
        print_fail "Configuration missing: $config"
    fi
done

echo ""

# Test 7: Check documentation
print_info "Testing documentation..."
if [ -f "${SCRIPT_DIR}/SUPPORTED_MODELS.md" ]; then
    print_pass "SUPPORTED_MODELS.md exists"
    
    # Check for required sections
    for section in "Model Registry" "Quantization Options" "Model Configuration" "Downloading Models"; do
        if grep -q "$section" "${SCRIPT_DIR}/SUPPORTED_MODELS.md"; then
            print_pass "Documentation contains section: $section"
        else
            print_fail "Documentation missing section: $section"
        fi
    done
else
    print_fail "SUPPORTED_MODELS.md missing"
fi

echo ""

# Summary
echo "=== Test Summary ==="
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi