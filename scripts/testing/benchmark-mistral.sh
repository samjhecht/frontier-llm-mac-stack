#!/bin/bash
# Mistral Performance Benchmarking Script
# Tests various performance aspects of Mistral.rs on Mac Studio

set -euo pipefail

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
MISTRAL_URL="${MISTRAL_URL:-http://localhost:8080}"
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_ROOT/benchmarks}"
TEST_MODEL="${TEST_MODEL:-mistral-7b-instruct}"
NUM_RUNS="${NUM_RUNS:-10}"
WARMUP_RUNS="${WARMUP_RUNS:-3}"

# Test prompts of varying complexity
declare -a TEST_PROMPTS=(
    "What is 2+2?"
    "Explain the concept of machine learning in one sentence."
    "Write a Python function that calculates the factorial of a number."
    "Explain quantum computing in detail, including its principles, applications, and current limitations."
    "Write a comprehensive guide on implementing a REST API in Python using FastAPI, including authentication, database integration, and deployment best practices."
)

declare -a PROMPT_NAMES=(
    "simple_math"
    "one_sentence"
    "code_generation"
    "detailed_explanation"
    "comprehensive_guide"
)

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if services are running
check_services() {
    print_info "Checking services..."
    
    if ! curl -s "${MISTRAL_URL}/health" > /dev/null 2>&1; then
        print_error "Mistral service is not running at ${MISTRAL_URL}"
        return 1
    fi
    
    if ! curl -s "${OLLAMA_URL}/" > /dev/null 2>&1; then
        print_warning "Ollama compatibility layer is not running at ${OLLAMA_URL}"
    fi
    
    print_success "Services are running"
    return 0
}

# Get system information
get_system_info() {
    print_info "System Information:"
    echo "  Hostname: $(hostname)"
    echo "  OS: $(uname -s) $(uname -r)"
    echo "  CPU: $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")"
    echo "  Memory: $(sysctl -n hw.memsize 2>/dev/null | awk '{print int($1/1024/1024/1024) " GB"}' || echo "Unknown")"
    
    # Check for Metal support
    if system_profiler SPDisplaysDataType 2>/dev/null | grep -q "Metal"; then
        echo "  GPU: Metal-capable GPU detected"
        system_profiler SPDisplaysDataType 2>/dev/null | grep -E "Chipset Model:|VRAM" | sed 's/^/    /'
    fi
    echo ""
}

# Benchmark inference latency
benchmark_latency() {
    local prompt="$1"
    local prompt_name="$2"
    local results_file="$3"
    
    print_info "Testing prompt: ${prompt_name}"
    
    # Warmup runs
    for ((i=1; i<=WARMUP_RUNS; i++)); do
        echo -n "  Warmup $i/$WARMUP_RUNS..."
        curl -s -X POST "${MISTRAL_URL}/v1/chat/completions" \
            -H "Content-Type: application/json" \
            -d "{
                \"model\": \"${TEST_MODEL}\",
                \"messages\": [{\"role\": \"user\", \"content\": \"${prompt}\"}],
                \"stream\": false
            }" > /dev/null
        echo " done"
    done
    
    # Actual benchmark runs
    local total_time=0
    local first_token_times=()
    local total_tokens=0
    
    echo "  Running benchmark..."
    for ((i=1; i<=NUM_RUNS; i++)); do
        local start_time=$(date +%s.%N)
        
        local response=$(curl -s -X POST "${MISTRAL_URL}/v1/chat/completions" \
            -H "Content-Type: application/json" \
            -d "{
                \"model\": \"${TEST_MODEL}\",
                \"messages\": [{\"role\": \"user\", \"content\": \"${prompt}\"}],
                \"stream\": false
            }")
        
        local end_time=$(date +%s.%N)
        local elapsed=$(echo "$end_time - $start_time" | bc)
        total_time=$(echo "$total_time + $elapsed" | bc)
        
        # Extract token count if available
        local tokens=$(echo "$response" | jq -r '.usage.total_tokens // 0' 2>/dev/null || echo "0")
        total_tokens=$((total_tokens + tokens))
        
        printf "    Run %2d: %.3fs (tokens: %d)\n" "$i" "$elapsed" "$tokens"
    done
    
    # Calculate statistics
    local avg_time=$(echo "scale=3; $total_time / $NUM_RUNS" | bc)
    local avg_tokens=$(echo "scale=0; $total_tokens / $NUM_RUNS" | bc)
    local tokens_per_second=$(echo "scale=2; $avg_tokens / $avg_time" | bc 2>/dev/null || echo "N/A")
    
    # Save results
    echo "${prompt_name},${avg_time},${avg_tokens},${tokens_per_second}" >> "$results_file"
    
    print_success "Average latency: ${avg_time}s, Tokens/sec: ${tokens_per_second}"
    echo ""
}

# Benchmark streaming performance
benchmark_streaming() {
    local prompt="Write a story about a robot learning to paint."
    local results_file="$1"
    
    print_info "Testing streaming performance..."
    
    local start_time=$(date +%s.%N)
    local chunk_count=0
    local first_chunk_time=""
    
    curl -s -X POST "${MISTRAL_URL}/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"${TEST_MODEL}\",
            \"messages\": [{\"role\": \"user\", \"content\": \"${prompt}\"}],
            \"stream\": true
        }" | while IFS= read -r line; do
        if [ -z "$first_chunk_time" ]; then
            first_chunk_time=$(date +%s.%N)
        fi
        ((chunk_count++))
    done
    
    local end_time=$(date +%s.%N)
    local total_time=$(echo "$end_time - $start_time" | bc)
    
    if [ -n "$first_chunk_time" ]; then
        local ttfb=$(echo "$first_chunk_time - $start_time" | bc)
        echo "streaming,${ttfb},${total_time},${chunk_count}" >> "$results_file"
        print_success "Time to first byte: ${ttfb}s, Total time: ${total_time}s, Chunks: ${chunk_count}"
    else
        print_warning "Streaming test failed"
    fi
    echo ""
}

# Check memory usage
check_memory_usage() {
    print_info "Checking memory usage..."
    
    if command -v docker &> /dev/null; then
        docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.CPUPerc}}" | grep -E "mistral|NAME"
    else
        print_warning "Docker not available, skipping memory check"
    fi
    echo ""
}

# Compare with Ollama if available
compare_with_ollama() {
    if ! command -v ollama &> /dev/null; then
        print_warning "Ollama CLI not found, skipping comparison"
        return
    fi
    
    print_info "Comparing with Ollama performance..."
    
    local ollama_start=$(date +%s.%N)
    ollama run mistral "What is 2+2?" > /dev/null 2>&1
    local ollama_end=$(date +%s.%N)
    local ollama_time=$(echo "$ollama_end - $ollama_start" | bc)
    
    print_info "Ollama latency: ${ollama_time}s"
    echo ""
}

# Main benchmark function
run_benchmarks() {
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local results_file="$OUTPUT_DIR/mistral_benchmark_${timestamp}.csv"
    local summary_file="$OUTPUT_DIR/mistral_benchmark_${timestamp}_summary.txt"
    
    # Initialize results file
    echo "test_name,avg_latency_sec,avg_tokens,tokens_per_sec" > "$results_file"
    
    # Start summary
    {
        echo "Mistral.rs Performance Benchmark Report"
        echo "======================================"
        echo "Timestamp: $(date)"
        echo ""
        get_system_info
    } > "$summary_file"
    
    # Check services
    check_services || exit 1
    
    # Run latency benchmarks
    print_info "Starting latency benchmarks (${NUM_RUNS} runs each)..."
    echo ""
    
    for i in "${!TEST_PROMPTS[@]}"; do
        benchmark_latency "${TEST_PROMPTS[$i]}" "${PROMPT_NAMES[$i]}" "$results_file"
    done
    
    # Run streaming benchmark
    benchmark_streaming "$results_file"
    
    # Check memory usage
    check_memory_usage | tee -a "$summary_file"
    
    # Compare with Ollama
    compare_with_ollama | tee -a "$summary_file"
    
    # Generate summary
    {
        echo "Benchmark Results"
        echo "-----------------"
        echo ""
        echo "Latency Results:"
        column -t -s',' "$results_file" | sed 's/^/  /'
        echo ""
        echo "Configuration:"
        echo "  Model: ${TEST_MODEL}"
        echo "  Runs per test: ${NUM_RUNS}"
        echo "  Warmup runs: ${WARMUP_RUNS}"
        echo ""
        echo "Results saved to:"
        echo "  CSV: $results_file"
        echo "  Summary: $summary_file"
    } | tee -a "$summary_file"
    
    print_success "Benchmarks completed!"
    echo ""
    echo "View results:"
    echo "  cat $summary_file"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--model)
            TEST_MODEL="$2"
            shift 2
            ;;
        -n|--num-runs)
            NUM_RUNS="$2"
            shift 2
            ;;
        -w|--warmup)
            WARMUP_RUNS="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -m, --model MODEL      Model to test (default: mistral-7b-instruct)"
            echo "  -n, --num-runs N       Number of benchmark runs (default: 10)"
            echo "  -w, --warmup N         Number of warmup runs (default: 3)"
            echo "  -o, --output DIR       Output directory (default: ./benchmarks)"
            echo "  -h, --help             Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run the benchmarks
run_benchmarks