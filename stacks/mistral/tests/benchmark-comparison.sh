#!/bin/bash
# Performance comparison benchmark for Mistral.rs vs Ollama

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
MISTRAL_URL="${MISTRAL_URL:-http://localhost:11434}"
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11435}"  # Different port for comparison
TEST_MODEL="${TEST_MODEL:-qwen2.5-coder:32b}"
OUTPUT_DIR="${OUTPUT_DIR:-./benchmark-results}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Benchmark parameters
ITERATIONS="${ITERATIONS:-10}"
CONCURRENT_REQUESTS="${CONCURRENT_REQUESTS:-5}"
PROMPT_SIZES=("short" "medium" "long")
MAX_TOKENS_LIST=(50 200 500)

# Create output directory
mkdir -p "$OUTPUT_DIR"
REPORT_FILE="$OUTPUT_DIR/benchmark-report-$TIMESTAMP.txt"
CSV_FILE="$OUTPUT_DIR/benchmark-results-$TIMESTAMP.csv"

# Utility functions
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}" | tee -a "$REPORT_FILE"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$REPORT_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$REPORT_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$REPORT_FILE"
}

# Generate prompts of different sizes
generate_prompt() {
    local size=$1
    case $size in
        "short")
            echo "What is 2+2?"
            ;;
        "medium")
            echo "Explain the concept of recursion in programming with a simple example."
            ;;
        "long")
            echo "Write a detailed explanation of how neural networks work, including the concepts of layers, weights, biases, activation functions, backpropagation, and gradient descent. Provide examples and discuss common architectures."
            ;;
    esac
}

# Check if services are available
check_services() {
    print_header "Service Availability Check"
    
    local services_ok=true
    
    # Check Mistral
    if curl -s "$MISTRAL_URL/api/tags" > /dev/null 2>&1; then
        print_info "Mistral.rs is accessible at $MISTRAL_URL"
    else
        print_error "Mistral.rs is not accessible at $MISTRAL_URL"
        services_ok=false
    fi
    
    # Check Ollama (optional for comparison)
    if curl -s "$OLLAMA_URL/api/tags" > /dev/null 2>&1; then
        print_info "Ollama is accessible at $OLLAMA_URL"
    else
        print_warning "Ollama is not accessible at $OLLAMA_URL - will only benchmark Mistral"
        OLLAMA_URL=""
    fi
    
    # Check if model is available
    if curl -s "$MISTRAL_URL/api/tags" | jq -e '.models[] | select(.name == "'$TEST_MODEL'")' > /dev/null 2>&1; then
        print_info "Model $TEST_MODEL is available in Mistral"
    else
        print_error "Model $TEST_MODEL is not available"
        services_ok=false
    fi
    
    if [ "$services_ok" = false ]; then
        exit 1
    fi
}

# Benchmark a single request
benchmark_request() {
    local url=$1
    local prompt=$2
    local max_tokens=$3
    local stream=${4:-false}
    
    local start_time=$(date +%s.%N)
    
    local response=$(curl -s -X POST "$url/api/generate" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$TEST_MODEL\",
            \"prompt\": \"$prompt\",
            \"max_tokens\": $max_tokens,
            \"stream\": $stream
        }" 2>/dev/null || echo "{\"error\": \"request failed\"}")
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    # Extract token count if available
    local token_count=0
    if echo "$response" | jq -e '.response' > /dev/null 2>&1; then
        token_count=$(echo "$response" | jq -r '.response' | wc -w)
    fi
    
    echo "$duration $token_count"
}

# Run latency benchmark
benchmark_latency() {
    local service_name=$1
    local url=$2
    
    print_header "Latency Benchmark - $service_name"
    
    echo "Service,PromptSize,MaxTokens,Iteration,Duration,TokenCount,TokensPerSecond" >> "$CSV_FILE"
    
    for prompt_size in "${PROMPT_SIZES[@]}"; do
        for max_tokens in "${MAX_TOKENS_LIST[@]}"; do
            print_info "Testing $prompt_size prompt with max_tokens=$max_tokens"
            
            local prompt=$(generate_prompt "$prompt_size")
            local total_duration=0
            local total_tokens=0
            local successful_runs=0
            
            for i in $(seq 1 $ITERATIONS); do
                echo -ne "\r  Progress: $i/$ITERATIONS"
                
                read duration token_count <<< $(benchmark_request "$url" "$prompt" "$max_tokens")
                
                if [ "$duration" != "0" ]; then
                    total_duration=$(echo "$total_duration + $duration" | bc)
                    total_tokens=$((total_tokens + token_count))
                    ((successful_runs++))
                    
                    # Calculate tokens per second
                    local tps=0
                    if [ "$token_count" -gt 0 ]; then
                        tps=$(echo "scale=2; $token_count / $duration" | bc)
                    fi
                    
                    echo "$service_name,$prompt_size,$max_tokens,$i,$duration,$token_count,$tps" >> "$CSV_FILE"
                fi
            done
            
            echo ""  # New line after progress
            
            if [ $successful_runs -gt 0 ]; then
                local avg_duration=$(echo "scale=3; $total_duration / $successful_runs" | bc)
                local avg_tokens=$(echo "scale=0; $total_tokens / $successful_runs" | bc)
                local avg_tps=0
                if [ "$avg_tokens" != "0" ]; then
                    avg_tps=$(echo "scale=2; $avg_tokens / $avg_duration" | bc)
                fi
                
                print_info "Average latency: ${avg_duration}s"
                print_info "Average tokens: $avg_tokens"
                print_info "Average tokens/sec: $avg_tps"
            else
                print_error "All requests failed for this configuration"
            fi
        done
    done
}

# Run throughput benchmark
benchmark_throughput() {
    local service_name=$1
    local url=$2
    
    print_header "Throughput Benchmark - $service_name"
    
    print_info "Sending $CONCURRENT_REQUESTS concurrent requests"
    
    local prompt=$(generate_prompt "medium")
    local start_time=$(date +%s.%N)
    
    # Launch concurrent requests
    local pids=""
    for i in $(seq 1 $CONCURRENT_REQUESTS); do
        (
            curl -s -X POST "$url/api/generate" \
                -H "Content-Type: application/json" \
                -d "{
                    \"model\": \"$TEST_MODEL\",
                    \"prompt\": \"$prompt\",
                    \"max_tokens\": 100,
                    \"stream\": false
                }" > /dev/null 2>&1
        ) &
        pids="$pids $!"
    done
    
    # Wait for all requests to complete
    local completed=0
    for pid in $pids; do
        if wait $pid; then
            ((completed++))
        fi
    done
    
    local end_time=$(date +%s.%N)
    local total_duration=$(echo "$end_time - $start_time" | bc)
    local rps=$(echo "scale=2; $completed / $total_duration" | bc)
    
    print_info "Completed $completed/$CONCURRENT_REQUESTS requests"
    print_info "Total time: ${total_duration}s"
    print_info "Throughput: $rps requests/second"
    
    echo "" >> "$CSV_FILE"
    echo "Throughput Test,$service_name,$CONCURRENT_REQUESTS,$completed,$total_duration,$rps" >> "$CSV_FILE"
}

# Run streaming benchmark
benchmark_streaming() {
    local service_name=$1
    local url=$2
    
    print_header "Streaming Benchmark - $service_name"
    
    local prompt=$(generate_prompt "medium")
    
    print_info "Testing streaming response time to first token"
    
    local total_ttft=0  # Time to first token
    local successful_runs=0
    
    for i in $(seq 1 5); do
        echo -ne "\r  Progress: $i/5"
        
        local start_time=$(date +%s.%N)
        
        # Get first chunk of streaming response
        local first_chunk=$(timeout 10 curl -s -N -X POST "$url/api/generate" \
            -H "Content-Type: application/json" \
            -d "{
                \"model\": \"$TEST_MODEL\",
                \"prompt\": \"$prompt\",
                \"stream\": true
            }" 2>/dev/null | head -n 1)
        
        if [ -n "$first_chunk" ]; then
            local end_time=$(date +%s.%N)
            local ttft=$(echo "$end_time - $start_time" | bc)
            total_ttft=$(echo "$total_ttft + $ttft" | bc)
            ((successful_runs++))
        fi
    done
    
    echo ""  # New line after progress
    
    if [ $successful_runs -gt 0 ]; then
        local avg_ttft=$(echo "scale=3; $total_ttft / $successful_runs" | bc)
        print_info "Average time to first token: ${avg_ttft}s"
    else
        print_error "Streaming tests failed"
    fi
}

# Run memory usage test
benchmark_memory() {
    local service_name=$1
    local container_name=$2
    
    print_header "Memory Usage - $service_name"
    
    if ! command -v docker &> /dev/null; then
        print_warning "Docker not available - skipping memory benchmark"
        return
    fi
    
    # Get container stats
    local stats=$(docker stats --no-stream --format "json" "$container_name" 2>/dev/null || echo "{}")
    
    if [ "$stats" != "{}" ]; then
        local memory=$(echo "$stats" | jq -r '.MemUsage' | cut -d'/' -f1)
        local cpu=$(echo "$stats" | jq -r '.CPUPerc')
        
        print_info "Memory usage: $memory"
        print_info "CPU usage: $cpu"
    else
        print_warning "Could not get container stats for $container_name"
    fi
}

# Generate comparison report
generate_report() {
    print_header "Performance Comparison Summary"
    
    if [ -n "$OLLAMA_URL" ]; then
        echo -e "\n${CYAN}Comparing Mistral.rs vs Ollama${NC}" | tee -a "$REPORT_FILE"
        
        # TODO: Add comparative analysis from CSV data
        print_info "Full results saved to: $CSV_FILE"
        print_info "Report saved to: $REPORT_FILE"
    else
        echo -e "\n${CYAN}Mistral.rs Benchmark Results${NC}" | tee -a "$REPORT_FILE"
        print_info "Results saved to: $CSV_FILE"
    fi
}

# Main execution
main() {
    echo "=== Performance Comparison Benchmark ===" | tee "$REPORT_FILE"
    echo "Timestamp: $(date)" | tee -a "$REPORT_FILE"
    echo "Model: $TEST_MODEL" | tee -a "$REPORT_FILE"
    echo "Iterations per test: $ITERATIONS" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
    
    # Check services
    check_services
    
    # Run benchmarks for Mistral
    benchmark_latency "Mistral" "$MISTRAL_URL"
    benchmark_throughput "Mistral" "$MISTRAL_URL"
    benchmark_streaming "Mistral" "$MISTRAL_URL"
    benchmark_memory "Mistral" "frontier-mistral-ollama-proxy"
    
    # Run benchmarks for Ollama if available
    if [ -n "$OLLAMA_URL" ]; then
        benchmark_latency "Ollama" "$OLLAMA_URL"
        benchmark_throughput "Ollama" "$OLLAMA_URL"
        benchmark_streaming "Ollama" "$OLLAMA_URL"
        benchmark_memory "Ollama" "frontier-ollama"
    fi
    
    # Generate report
    generate_report
    
    echo -e "\n${GREEN}Benchmark completed!${NC}"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --iterations)
            ITERATIONS="$2"
            shift 2
            ;;
        --concurrent)
            CONCURRENT_REQUESTS="$2"
            shift 2
            ;;
        --model)
            TEST_MODEL="$2"
            shift 2
            ;;
        --mistral-url)
            MISTRAL_URL="$2"
            shift 2
            ;;
        --ollama-url)
            OLLAMA_URL="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --iterations N       Number of iterations per test (default: 10)"
            echo "  --concurrent N       Number of concurrent requests (default: 5)"
            echo "  --model MODEL        Model to test (default: qwen2.5-coder:32b)"
            echo "  --mistral-url URL    Mistral API URL (default: http://localhost:11434)"
            echo "  --ollama-url URL     Ollama API URL for comparison (optional)"
            echo "  --output-dir DIR     Output directory for results (default: ./benchmark-results)"
            echo "  --help               Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main
fi