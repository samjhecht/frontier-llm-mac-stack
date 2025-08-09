#!/bin/bash
# Advanced Aider integration tests for Mistral.rs

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
    # Clean up test directory
    if [ -n "${TEST_DIR:-}" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
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
OLLAMA_API_BASE="${OLLAMA_API_BASE:-http://localhost:11434}"
TEST_MODEL="${TEST_MODEL:-qwen2.5-coder:32b}"
TEST_DIR=$(mktemp -d)
PASSED=0
FAILED=0

# Utility functions
print_test() {
    echo -en "${BLUE}TEST:${NC} $1... "
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

cleanup() {
    rm -rf "$TEST_DIR"
}

trap cleanup EXIT

# Check prerequisites
check_prerequisites() {
    echo "=== Checking Prerequisites ==="
    
    if ! command -v aider &> /dev/null; then
        echo -e "${RED}Error: Aider is not installed${NC}"
        echo "Install with: pip install aider-chat"
        exit 1
    fi
    
    if ! curl -s "$OLLAMA_API_BASE/api/tags" > /dev/null 2>&1; then
        echo -e "${RED}Error: Cannot connect to Mistral API at $OLLAMA_API_BASE${NC}"
        exit 1
    fi
    
    if ! curl -s "$OLLAMA_API_BASE/api/tags" | jq -e '.models[] | select(.name == "'$TEST_MODEL'")' > /dev/null 2>&1; then
        echo -e "${YELLOW}Warning: Model $TEST_MODEL not found${NC}"
        echo "Available models:"
        curl -s "$OLLAMA_API_BASE/api/tags" | jq -r '.models[].name'
        exit 1
    fi
    
    echo -e "${GREEN}Prerequisites satisfied${NC}\n"
}

# Test 1: Basic Aider functionality
test_basic_functionality() {
    print_test "Basic Aider functionality"
    
    cd "$TEST_DIR"
    git init > /dev/null 2>&1
    
    # Create a simple Python file
    cat > hello.py << 'EOF'
def greet():
    pass
EOF
    
    # Test basic code generation
    if echo "implement the greet function to print 'Hello, World!'" | \
       timeout 30 aider --model "ollama/$TEST_MODEL" --no-auto-commits --yes hello.py 2>&1 | \
       grep -q "Hello, World"; then
        if grep -q "print.*Hello, World" hello.py; then
            print_pass
        else
            print_fail "Code was not properly generated"
        fi
    else
        print_fail "Aider command failed or timed out"
    fi
}

# Test 2: Multiple file handling
test_multiple_files() {
    print_test "Multiple file handling"
    
    cd "$TEST_DIR"
    
    # Create multiple files
    cat > math_ops.py << 'EOF'
def add(a, b):
    pass

def multiply(a, b):
    pass
EOF
    
    cat > string_ops.py << 'EOF'
def concatenate(s1, s2):
    pass

def reverse(s):
    pass
EOF
    
    # Test editing multiple files
    if echo "implement all the functions in both files" | \
       timeout 45 aider --model "ollama/$TEST_MODEL" --no-auto-commits --yes math_ops.py string_ops.py 2>&1 > /dev/null; then
        
        # Check implementations
        if grep -q "return a + b" math_ops.py && \
           grep -q "return a \* b" math_ops.py && \
           grep -q "return s1 + s2" string_ops.py && \
           grep -q "return s\[::-1\]" string_ops.py; then
            print_pass
        else
            print_fail "Not all functions were properly implemented"
        fi
    else
        print_fail "Aider failed to handle multiple files"
    fi
}

# Test 3: Context window management
test_context_window() {
    print_test "Context window management"
    
    cd "$TEST_DIR"
    
    # Create a large file
    cat > large_file.py << 'EOF'
# This is a large file to test context window handling
class DataProcessor:
    def __init__(self):
        self.data = []
        
    def load_data(self, filename):
        """Load data from a file"""
        pass
        
    def process_data(self):
        """Process the loaded data"""
        pass
        
    def save_results(self, filename):
        """Save processed results to a file"""
        pass
        
    def analyze_data(self):
        """Analyze the data and return statistics"""
        pass
        
    def visualize_data(self):
        """Create visualizations of the data"""
        pass
EOF
    
    # Add more content to make it larger
    for i in {1..50}; do
        echo "    def method_$i(self):" >> large_file.py
        echo "        \"\"\"Method $i documentation\"\"\"" >> large_file.py
        echo "        pass" >> large_file.py
        echo "" >> large_file.py
    done
    
    # Test handling large file
    if echo "implement the load_data method to read a CSV file" | \
       timeout 40 aider --model "ollama/$TEST_MODEL" --no-auto-commits --yes large_file.py 2>&1 > /dev/null; then
        
        if grep -q "import csv" large_file.py || grep -q "open.*filename" large_file.py; then
            print_pass
        else
            print_fail "Implementation not added to large file"
        fi
    else
        print_fail "Failed to handle large file"
    fi
}

# Test 4: Refactoring capabilities
test_refactoring() {
    print_test "Refactoring capabilities"
    
    cd "$TEST_DIR"
    
    # Create code that needs refactoring
    cat > messy_code.py << 'EOF'
def calculate(x, y, operation):
    if operation == "add":
        return x + y
    elif operation == "subtract":
        return x - y
    elif operation == "multiply":
        return x * y
    elif operation == "divide":
        if y != 0:
            return x / y
        else:
            return None
    else:
        return None
EOF
    
    # Test refactoring
    if echo "refactor this code to use a dictionary dispatch pattern instead of if-elif chains" | \
       timeout 45 aider --model "ollama/$TEST_MODEL" --no-auto-commits --yes messy_code.py 2>&1 > /dev/null; then
        
        if grep -q "operations\s*=" messy_code.py || grep -q "dispatch" messy_code.py; then
            print_pass
        else
            print_fail "Code was not properly refactored"
        fi
    else
        print_fail "Refactoring request failed"
    fi
}

# Test 5: Error correction
test_error_correction() {
    print_test "Error correction"
    
    cd "$TEST_DIR"
    
    # Create code with errors
    cat > buggy_code.py << 'EOF'
def find_max(numbers):
    max_num = numbers[0]
    for i in range(len(numbers)):
        if numbers[i] > max_num
            max_num = numbers[i]
    return max_num

def calculate_average(numbers):
    total = sum(numbers)
    return total / len(numbers)
EOF
    
    # Test error fixing
    if echo "fix the syntax errors in this code" | \
       timeout 30 aider --model "ollama/$TEST_MODEL" --no-auto-commits --yes buggy_code.py 2>&1 > /dev/null; then
        
        # Check if syntax is valid
        if python -m py_compile buggy_code.py 2>/dev/null; then
            print_pass
        else
            print_fail "Syntax errors were not fixed"
        fi
    else
        print_fail "Error correction failed"
    fi
}

# Test 6: Documentation generation
test_documentation() {
    print_test "Documentation generation"
    
    cd "$TEST_DIR"
    
    # Create undocumented code
    cat > undocumented.py << 'EOF'
class Calculator:
    def add(self, a, b):
        return a + b
    
    def factorial(self, n):
        if n <= 1:
            return 1
        return n * self.factorial(n - 1)
    
    def is_prime(self, n):
        if n < 2:
            return False
        for i in range(2, int(n ** 0.5) + 1):
            if n % i == 0:
                return False
        return True
EOF
    
    # Test documentation generation
    if echo "add comprehensive docstrings to all methods in this class" | \
       timeout 40 aider --model "ollama/$TEST_MODEL" --no-auto-commits --yes undocumented.py 2>&1 > /dev/null; then
        
        # Count docstrings
        docstring_count=$(grep -c '"""' undocumented.py || echo "0")
        
        # Expect at least 3 methods * 2 quotes each for docstrings
        MIN_DOCSTRING_COUNT="${MIN_DOCSTRING_COUNT:-6}"
        if [ "$docstring_count" -ge "$MIN_DOCSTRING_COUNT" ]; then
            print_pass
        else
            print_fail "Insufficient documentation added"
        fi
    else
        print_fail "Documentation generation failed"
    fi
}

# Test 7: Interactive commands
test_interactive_commands() {
    print_test "Interactive Aider commands"
    
    cd "$TEST_DIR"
    
    # Create a test file
    echo "x = 1" > test.py
    
    # Test various Aider commands
    commands=(
        "/help"
        "/tokens"
        "/clear"
    )
    
    success=true
    for cmd in "${commands[@]}"; do
        if ! echo "$cmd" | timeout 10 aider --model "ollama/$TEST_MODEL" --no-auto-commits --yes test.py 2>&1 > /dev/null; then
            success=false
            break
        fi
    done
    
    if $success; then
        print_pass
    else
        print_fail "Some interactive commands failed"
    fi
}

# Test 8: Long conversation handling
test_long_conversation() {
    print_test "Long conversation handling"
    
    cd "$TEST_DIR"
    
    # Create initial file
    cat > app.py << 'EOF'
class TodoList:
    def __init__(self):
        self.tasks = []
EOF
    
    # Simulate a long conversation with multiple requests
    conversation=(
        "add a method to add tasks"
        "add a method to remove tasks by index"
        "add a method to mark tasks as complete"
        "add a method to list all tasks"
        "add error handling to all methods"
    )
    
    success=true
    for request in "${conversation[@]}"; do
        if ! echo "$request" | timeout 30 aider --model "ollama/$TEST_MODEL" --no-auto-commits --yes app.py 2>&1 > /dev/null; then
            success=false
            break
        fi
    done
    
    if $success; then
        # Verify the file has grown with implementations
        line_count=$(wc -l < app.py)
        if [ "$line_count" -gt 20 ]; then
            print_pass
        else
            print_fail "Not enough code was generated in long conversation"
        fi
    else
        print_fail "Long conversation handling failed"
    fi
}

# Main test runner
main() {
    echo "=== Advanced Aider Integration Tests for Mistral.rs ==="
    echo "API Base: $OLLAMA_API_BASE"
    echo "Test Model: $TEST_MODEL"
    echo ""
    
    check_prerequisites
    
    # Run all tests
    test_basic_functionality
    test_multiple_files
    test_context_window
    test_refactoring
    test_error_correction
    test_documentation
    test_interactive_commands
    test_long_conversation
    
    # Summary
    echo ""
    echo "=== Test Summary ==="
    echo -e "Passed: ${GREEN}$PASSED${NC}"
    echo -e "Failed: ${RED}$FAILED${NC}"
    
    if [ $FAILED -eq 0 ]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed${NC}"
        exit 1
    fi
}

# Run main if not sourced
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main
fi