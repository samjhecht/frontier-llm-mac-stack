#!/bin/bash
# Master test runner for Mistral.rs integration tests

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
    # Clean up any temporary files and report files
    rm -f /tmp/mistral-test-*
    exit $exit_code
}
trap cleanup EXIT INT TERM

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

# Test configuration
TEST_MODEL="${TEST_MODEL:-qwen2.5-coder:32b}"
SKIP_BENCHMARK="${SKIP_BENCHMARK:-false}"
VERBOSE="${VERBOSE:-false}"

# Results tracking
RESULTS_DIR="$SCRIPT_DIR/results"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SUMMARY_FILE="$RESULTS_DIR/test-summary-$TIMESTAMP.txt"

# Test suite tracking
# Using regular arrays for compatibility with older bash versions
TEST_RESULTS_KEYS=()
TEST_RESULTS_VALUES=()
TEST_SUITES=(
    "integration:Integration Tests:integration-test.sh"
    "aider:Aider Advanced Tests:test-aider-advanced.sh"
    "monitoring:Monitoring Advanced Tests:test-monitoring-advanced.sh"
    "benchmark:Performance Benchmark:benchmark-comparison.sh"
)

# Helper functions for associative array emulation
set_test_result() {
    local key=$1
    local value=$2
    local index=-1
    
    # Check if key exists
    for i in "${!TEST_RESULTS_KEYS[@]}"; do
        if [ "${TEST_RESULTS_KEYS[$i]}" = "$key" ]; then
            index=$i
            break
        fi
    done
    
    if [ $index -eq -1 ]; then
        # Add new key-value pair
        TEST_RESULTS_KEYS+=("$key")
        TEST_RESULTS_VALUES+=("$value")
    else
        # Update existing value
        TEST_RESULTS_VALUES[$index]="$value"
    fi
}

get_test_result() {
    local key=$1
    
    for i in "${!TEST_RESULTS_KEYS[@]}"; do
        if [ "${TEST_RESULTS_KEYS[$i]}" = "$key" ]; then
            echo "${TEST_RESULTS_VALUES[$i]}"
            return
        fi
    done
    
    echo "NOT_RUN"
}

# Utility functions
print_header() {
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BLUE}$1${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
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

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_failure() {
    echo -e "${RED}✗${NC} $1"
}

# Create results directory
setup_results_dir() {
    mkdir -p "$RESULTS_DIR"
    echo "Mistral.rs Test Suite Execution Summary" > "$SUMMARY_FILE"
    echo "=======================================" >> "$SUMMARY_FILE"
    echo "Timestamp: $(date)" >> "$SUMMARY_FILE"
    echo "Test Model: $TEST_MODEL" >> "$SUMMARY_FILE"
    echo "" >> "$SUMMARY_FILE"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local all_good=true
    
    # Check if Mistral services are running
    print_info "Checking Mistral services..."
    if docker ps | grep -q "frontier-mistral"; then
        print_success "Mistral services are running"
    elif curl -s http://localhost:8080/health >/dev/null 2>&1; then
        print_warning "Using mock server on port 8080"
    else
        print_error "Mistral services are not running"
        print_info "Please start the services with: cd $ROOT_DIR && ./start.sh"
        all_good=false
    fi
    
    # Check if monitoring services are running
    print_info "Checking monitoring services..."
    if docker ps | grep -q "prometheus"; then
        print_success "Monitoring services are running"
    else
        print_warning "Monitoring services are not running - some tests will be skipped"
    fi
    
    # Check if model is available
    print_info "Checking model availability..."
    local model_response=$(curl -s "http://localhost:11434/api/tags" 2>/dev/null)
    if [ -n "$model_response" ] && echo "$model_response" | jq -e '.models[] | select(.name == "'$TEST_MODEL'")' > /dev/null 2>&1; then
        print_success "Model $TEST_MODEL is available"
    elif [ -n "$model_response" ] && echo "$model_response" | jq -e '.models' > /dev/null 2>&1; then
        print_warning "Model $TEST_MODEL is not available - using mock server"
        print_info "Available models:"
        echo "$model_response" | jq -r '.models[].name' 2>/dev/null | sed 's/^/  - /'
    else
        print_warning "Using mock server - model checks bypassed"
    fi
    
    # Check Aider installation
    if command -v aider &> /dev/null; then
        print_success "Aider is installed"
    else
        print_warning "Aider is not installed - Aider tests will be skipped"
    fi
    
    if [ "$all_good" = false ]; then
        print_error "Prerequisites check failed. Please fix the issues above and try again."
        exit 1
    fi
    
    echo ""
}

# Run a test suite
run_test_suite() {
    local suite_id=$1
    local suite_name=$2
    local script_name=$3
    local script_path="$SCRIPT_DIR/$script_name"
    
    print_header "Running $suite_name"
    
    # Skip benchmark if requested
    if [ "$suite_id" = "benchmark" ] && [ "$SKIP_BENCHMARK" = "true" ]; then
        print_warning "Skipping benchmark tests (SKIP_BENCHMARK=true)"
        set_test_result "$suite_id" "SKIPPED"
        return
    fi
    
    # Check if script exists
    if [ ! -f "$script_path" ]; then
        print_error "Test script not found: $script_path"
        set_test_result "$suite_id" "NOT_FOUND"
        return
    fi
    
    # Create output file for this test suite
    local output_file="$RESULTS_DIR/${suite_id}-output-$TIMESTAMP.log"
    
    print_info "Running tests..."
    print_info "Output will be saved to: $output_file"
    
    # Run the test
    if [ "$VERBOSE" = "true" ]; then
        # Show output in real-time
        if bash "$script_path" 2>&1 | tee "$output_file"; then
            set_test_result "$suite_id" "PASSED"
            print_success "$suite_name completed successfully"
        else
            set_test_result "$suite_id" "FAILED"
            print_failure "$suite_name failed"
        fi
    else
        # Run quietly, only show summary
        if bash "$script_path" > "$output_file" 2>&1; then
            set_test_result "$suite_id" "PASSED"
            print_success "$suite_name completed successfully"
            
            # Extract summary from output if available
            if grep -q "Test Summary" "$output_file"; then
                echo ""
                sed -n '/Test Summary/,/^$/p' "$output_file" | head -10
            fi
        else
            set_test_result "$suite_id" "FAILED"
            print_failure "$suite_name failed"
            
            # Show last few lines of error
            echo "Last 5 lines of output:"
            tail -5 "$output_file" | sed 's/^/  /'
        fi
    fi
    
    echo ""
}

# Generate final report
generate_report() {
    print_header "Test Execution Summary"
    
    local passed=0
    local failed=0
    local skipped=0
    
    echo "Test Results:" | tee -a "$SUMMARY_FILE"
    echo "-------------" | tee -a "$SUMMARY_FILE"
    
    for suite_info in "${TEST_SUITES[@]}"; do
        IFS=':' read -r suite_id suite_name script_name <<< "$suite_info"
        local result=$(get_test_result "$suite_id")
        
        case $result in
            PASSED)
                echo -e "${GREEN}✓${NC} $suite_name: PASSED" | tee -a "$SUMMARY_FILE"
                ((passed++))
                ;;
            FAILED)
                echo -e "${RED}✗${NC} $suite_name: FAILED" | tee -a "$SUMMARY_FILE"
                ((failed++))
                ;;
            SKIPPED)
                echo -e "${YELLOW}⚠${NC} $suite_name: SKIPPED" | tee -a "$SUMMARY_FILE"
                ((skipped++))
                ;;
            *)
                echo -e "${YELLOW}?${NC} $suite_name: $result" | tee -a "$SUMMARY_FILE"
                ((skipped++))
                ;;
        esac
    done
    
    echo "" | tee -a "$SUMMARY_FILE"
    echo "Summary:" | tee -a "$SUMMARY_FILE"
    echo "  Passed:  $passed" | tee -a "$SUMMARY_FILE"
    echo "  Failed:  $failed" | tee -a "$SUMMARY_FILE"
    echo "  Skipped: $skipped" | tee -a "$SUMMARY_FILE"
    
    echo "" | tee -a "$SUMMARY_FILE"
    echo "Results saved to: $RESULTS_DIR" | tee -a "$SUMMARY_FILE"
    echo "Summary file: $SUMMARY_FILE" | tee -a "$SUMMARY_FILE"
    
    # Exit code based on failures
    if [ $failed -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

# Show usage
usage() {
    echo "Usage: $0 [options] [test-suite]"
    echo ""
    echo "Run all or specific Mistral.rs integration tests"
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -v, --verbose        Show detailed test output"
    echo "  -s, --skip-benchmark Skip performance benchmark tests"
    echo "  -m, --model MODEL    Specify test model (default: $TEST_MODEL)"
    echo ""
    echo "Test Suites:"
    echo "  all          Run all test suites (default)"
    echo "  integration  Run integration tests only"
    echo "  aider        Run Aider tests only"
    echo "  monitoring   Run monitoring tests only"
    echo "  benchmark    Run performance benchmark only"
    echo ""
    echo "Examples:"
    echo "  $0                    # Run all tests"
    echo "  $0 -v integration     # Run integration tests with verbose output"
    echo "  $0 -s                 # Run all tests except benchmark"
    echo "  $0 -m mistral:latest  # Run tests with different model"
}

# Parse command line arguments
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -s|--skip-benchmark)
            SKIP_BENCHMARK=true
            shift
            ;;
        -m|--model)
            TEST_MODEL="$2"
            shift 2
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# Restore positional parameters
if [ ${#POSITIONAL_ARGS[@]} -gt 0 ]; then
    set -- "${POSITIONAL_ARGS[@]}"
else
    set --
fi

# Determine which tests to run
TEST_SUITE="${1:-all}"

# Main execution
main() {
    print_header "Mistral.rs Integration Test Suite"
    
    print_info "Test Configuration:"
    print_info "  Model: $TEST_MODEL"
    print_info "  Verbose: $VERBOSE"
    print_info "  Skip Benchmark: $SKIP_BENCHMARK"
    print_info "  Test Suite: $TEST_SUITE"
    
    # Setup
    setup_results_dir
    check_prerequisites
    
    # Run tests based on selection
    case $TEST_SUITE in
        all)
            for suite_info in "${TEST_SUITES[@]}"; do
                IFS=':' read -r suite_id suite_name script_name <<< "$suite_info"
                run_test_suite "$suite_id" "$suite_name" "$script_name"
            done
            ;;
        integration|aider|monitoring|benchmark)
            # Find and run specific test suite
            for suite_info in "${TEST_SUITES[@]}"; do
                IFS=':' read -r suite_id suite_name script_name <<< "$suite_info"
                if [ "$suite_id" = "$TEST_SUITE" ]; then
                    run_test_suite "$suite_id" "$suite_name" "$script_name"
                    break
                fi
            done
            ;;
        *)
            print_error "Unknown test suite: $TEST_SUITE"
            usage
            exit 1
            ;;
    esac
    
    # Generate report
    generate_report
}

# Run main
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main
fi