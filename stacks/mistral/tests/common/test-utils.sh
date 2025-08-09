#!/bin/bash
# Common test utility functions

# Source colors if not already sourced
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -z "${GREEN:-}" ]; then
    source "$SCRIPT_DIR/colors.sh"
fi

# Test counters (initialize if not set)
PASSED="${PASSED:-0}"
FAILED="${FAILED:-0}"
SKIPPED="${SKIPPED:-0}"

# Print functions
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_test() {
    echo -ne "${CYAN}Testing:${NC} $1... "
}

print_pass() {
    echo -e "${GREEN}✓ PASSED${NC}"
    ((PASSED++))
}

print_fail() {
    echo -e "${RED}✗ FAILED${NC}"
    if [ -n "${1:-}" ]; then
        echo -e "  ${RED}Error: $1${NC}"
    fi
    ((FAILED++))
}

print_skip() {
    echo -e "${YELLOW}⊘ SKIPPED${NC}"
    if [ -n "${1:-}" ]; then
        echo -e "  ${YELLOW}Reason: $1${NC}"
    fi
    ((SKIPPED++))
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if service is running
check_service() {
    local service_name=$1
    local port=$2
    
    if curl -s -f "http://localhost:$port" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Check prerequisites
check_prerequisites() {
    local missing=()
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Error: Required commands not installed: ${missing[*]}" >&2
        echo "Please install missing dependencies and try again." >&2
        exit 1
    fi
}

# Validate numeric input
validate_numeric() {
    local value=$1
    local name=$2
    
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        print_error "Invalid $name: '$value' is not a valid number"
        exit 1
    fi
}

# Generate test summary
print_summary() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}            TEST SUMMARY                ${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    local total=$((PASSED + FAILED + SKIPPED))
    echo -e "Total Tests: $total"
    echo -e "${GREEN}Passed: $PASSED${NC}"
    echo -e "${RED}Failed: $FAILED${NC}"
    echo -e "${YELLOW}Skipped: $SKIPPED${NC}"
    
    if [ $FAILED -eq 0 ]; then
        echo -e "\n${GREEN}✓ All tests passed successfully!${NC}"
        return 0
    else
        echo -e "\n${RED}✗ Some tests failed${NC}"
        return 1
    fi
}

# Retry function with exponential backoff
retry_with_backoff() {
    local max_retries=${1:-3}
    local delay=${2:-1}
    local max_delay=${3:-10}
    shift 3
    
    local attempt=0
    while [ $attempt -lt $max_retries ]; do
        if "$@"; then
            return 0
        fi
        
        ((attempt++))
        if [ $attempt -lt $max_retries ]; then
            print_warning "Attempt $attempt failed, retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * 2))
            if [ $delay -gt $max_delay ]; then
                delay=$max_delay
            fi
        fi
    done
    
    return 1
}