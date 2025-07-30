#!/bin/bash
set -euo pipefail

# benchmark-llm.sh - Comprehensive benchmarking tool for Ollama models
# Tests response time, throughput, and resource usage

echo "=== LLM Performance Benchmarking Tool ==="

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
OLLAMA_HOST="${OLLAMA_HOST:-localhost}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
OLLAMA_URL="http://${OLLAMA_HOST}:${OLLAMA_PORT}"
RESULTS_DIR="./benchmark-results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Function to print colored output
print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_header() { echo -e "\n${BLUE}=== $1 ===${NC}\n"; }

# Check Ollama availability
check_ollama() {
    if ! curl -s "${OLLAMA_URL}/api/version" > /dev/null 2>&1; then
        print_error "Cannot connect to Ollama at ${OLLAMA_URL}"
        exit 1
    fi
    print_status "Connected to Ollama at ${OLLAMA_URL}"
}

# Create results directory
mkdir -p "$RESULTS_DIR"

# Test prompts for different scenarios
declare -A TEST_PROMPTS=(
    ["simple"]="What is 2+2?"
    ["code_generation"]="Write a Python function to calculate the factorial of a number"
    ["code_explanation"]="Explain what this code does: def fib(n): return n if n<=1 else fib(n-1)+fib(n-2)"
    ["refactoring"]="Refactor this code to be more efficient: for i in range(len(arr)): for j in range(len(arr)): if arr[i] > arr[j]: temp = arr[i]; arr[i] = arr[j]; arr[j] = temp"
    ["debugging"]="Find and fix the bug in this code: def divide(a, b): return a / b"
    ["long_context"]="$(printf 'Analyze this log file and identify any errors or issues:\n'; for i in {1..50}; do echo "2024-01-01 12:00:$i INFO: Processing request $i"; done; echo "2024-01-01 12:00:51 ERROR: Connection timeout"; for i in {52..100}; do echo "2024-01-01 12:00:$i INFO: Processing request $i"; done)"
)

# Function to measure response time
measure_response_time() {
    local model=$1
    local prompt=$2
    local prompt_name=$3
    
    print_status "Testing: $prompt_name"
    
    # Record start time
    start_time=$(date +%s.%N)
    
    # Make API call
    response=$(curl -s -X POST "${OLLAMA_URL}/api/generate" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "'"$model"'",
            "prompt": "'"$(echo "$prompt" | sed 's/"/\\"/g')"'",
            "stream": false
        }' 2>&1)
    
    # Record end time
    end_time=$(date +%s.%N)
    
    # Calculate duration
    duration=$(echo "$end_time - $start_time" | bc)
    
    # Extract token counts if available
    total_tokens=$(echo "$response" | jq -r '.eval_count + .prompt_eval_count' 2>/dev/null || echo "0")
    eval_tokens=$(echo "$response" | jq -r '.eval_count' 2>/dev/null || echo "0")
    
    # Calculate tokens per second
    if [[ "$eval_tokens" != "0" && "$eval_tokens" != "null" ]]; then
        tokens_per_sec=$(echo "scale=2; $eval_tokens / $duration" | bc)
    else
        tokens_per_sec="N/A"
    fi
    
    echo "$prompt_name,$duration,$total_tokens,$tokens_per_sec"
}

# Function to run streaming benchmark
streaming_benchmark() {
    local model=$1
    local prompt="Write a detailed explanation of how neural networks work"
    
    print_header "Streaming Benchmark"
    print_status "Testing streaming response..."
    
    start_time=$(date +%s.%N)
    first_token_time=""
    token_count=0
    
    # Stream response and measure time to first token
    curl -s -X POST "${OLLAMA_URL}/api/generate" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "'"$model"'",
            "prompt": "'"$prompt"'",
            "stream": true
        }' | while IFS= read -r line; do
            if [[ -z "$first_token_time" ]]; then
                first_token_time=$(date +%s.%N)
            fi
            token_count=$((token_count + 1))
            
            # Show progress
            if [[ $((token_count % 10)) -eq 0 ]]; then
                echo -n "."
            fi
        done
    
    end_time=$(date +%s.%N)
    
    if [[ -n "$first_token_time" ]]; then
        time_to_first_token=$(echo "$first_token_time - $start_time" | bc)
        total_time=$(echo "$end_time - $start_time" | bc)
        
        echo ""
        print_status "Time to first token: ${time_to_first_token}s"
        print_status "Total streaming time: ${total_time}s"
    fi
}

# Function to monitor system resources during benchmark
monitor_resources() {
    local pid=$1
    local output_file=$2
    
    echo "timestamp,cpu_percent,memory_mb" > "$output_file"
    
    while kill -0 $pid 2>/dev/null; do
        timestamp=$(date +%s)
        
        if [[ "$(uname)" == "Darwin" ]]; then
            # macOS resource monitoring
            cpu_usage=$(ps aux | grep ollama | grep -v grep | awk '{print $3}' | head -1)
            memory_mb=$(ps aux | grep ollama | grep -v grep | awk '{print $6}' | head -1 | awk '{print $1/1024}')
        else
            # Linux resource monitoring
            cpu_usage=$(top -b -n 1 -p $pid | tail -1 | awk '{print $9}')
            memory_mb=$(ps -p $pid -o rss= | awk '{print $1/1024}')
        fi
        
        echo "$timestamp,$cpu_usage,$memory_mb" >> "$output_file"
        sleep 1
    done
}

# Function to run concurrent request benchmark
concurrent_benchmark() {
    local model=$1
    local num_concurrent=$2
    
    print_header "Concurrent Request Benchmark ($num_concurrent parallel requests)"
    
    temp_dir=$(mktemp -d)
    
    # Start concurrent requests
    for i in $(seq 1 $num_concurrent); do
        (
            start_time=$(date +%s.%N)
            curl -s -X POST "${OLLAMA_URL}/api/generate" \
                -H "Content-Type: application/json" \
                -d '{
                    "model": "'"$model"'",
                    "prompt": "Generate a random number between 1 and 100",
                    "stream": false
                }' > /dev/null
            end_time=$(date +%s.%N)
            duration=$(echo "$end_time - $start_time" | bc)
            echo "$duration" > "$temp_dir/request_$i.time"
        ) &
    done
    
    # Wait for all requests to complete
    wait
    
    # Calculate statistics
    total_time=0
    max_time=0
    min_time=999999
    
    for file in "$temp_dir"/*.time; do
        time=$(cat "$file")
        total_time=$(echo "$total_time + $time" | bc)
        
        if (( $(echo "$time > $max_time" | bc -l) )); then
            max_time=$time
        fi
        
        if (( $(echo "$time < $min_time" | bc -l) )); then
            min_time=$time
        fi
    done
    
    avg_time=$(echo "scale=2; $total_time / $num_concurrent" | bc)
    
    print_status "Average response time: ${avg_time}s"
    print_status "Min response time: ${min_time}s"
    print_status "Max response time: ${max_time}s"
    
    rm -rf "$temp_dir"
}

# Main benchmark function
run_benchmark() {
    local model=$1
    
    print_header "Benchmarking Model: $model"
    
    # Create result file
    result_file="$RESULTS_DIR/benchmark_${model//\//_}_${TIMESTAMP}.csv"
    
    # Check if model exists
    if ! ollama list | grep -q "$model"; then
        print_error "Model $model not found. Please pull it first."
        return 1
    fi
    
    # Get model info
    print_status "Model Information:"
    ollama show "$model" --modelfile | head -20
    
    # Start resource monitoring
    ollama_pid=$(pgrep -f "ollama serve" | head -1)
    if [[ -n "$ollama_pid" ]]; then
        monitor_resources "$ollama_pid" "$RESULTS_DIR/resources_${model//\//_}_${TIMESTAMP}.csv" &
        monitor_pid=$!
    fi
    
    # Run response time benchmarks
    print_header "Response Time Benchmarks"
    echo "test_name,response_time_seconds,total_tokens,tokens_per_second" > "$result_file"
    
    for prompt_name in "${!TEST_PROMPTS[@]}"; do
        result=$(measure_response_time "$model" "${TEST_PROMPTS[$prompt_name]}" "$prompt_name")
        echo "$result" >> "$result_file"
        echo "$result" | column -t -s ','
    done
    
    # Run streaming benchmark
    streaming_benchmark "$model"
    
    # Run concurrent request benchmark
    for concurrent in 1 2 4 8; do
        concurrent_benchmark "$model" "$concurrent"
    done
    
    # Stop resource monitoring
    if [[ -n "${monitor_pid:-}" ]]; then
        kill $monitor_pid 2>/dev/null || true
    fi
    
    # Generate summary report
    print_header "Benchmark Summary"
    print_status "Results saved to: $result_file"
    
    # Calculate average response time
    avg_response_time=$(awk -F',' 'NR>1 {sum+=$2; count++} END {print sum/count}' "$result_file")
    print_status "Average response time: ${avg_response_time}s"
    
    # Show token throughput
    avg_tokens_per_sec=$(awk -F',' 'NR>1 && $4 != "N/A" {sum+=$4; count++} END {if(count>0) print sum/count; else print "N/A"}' "$result_file")
    print_status "Average tokens/second: $avg_tokens_per_sec"
}

# Comparison function
compare_models() {
    print_header "Model Comparison Mode"
    
    # Get list of installed models
    models=($(ollama list | tail -n +2 | awk '{print $1}'))
    
    if [[ ${#models[@]} -eq 0 ]]; then
        print_error "No models found. Please pull some models first."
        exit 1
    fi
    
    print_status "Found ${#models[@]} models"
    
    comparison_file="$RESULTS_DIR/comparison_${TIMESTAMP}.csv"
    echo "model,avg_response_time,avg_tokens_per_sec" > "$comparison_file"
    
    for model in "${models[@]}"; do
        print_header "Benchmarking: $model"
        
        # Run simplified benchmark for comparison
        total_time=0
        total_tokens=0
        
        for i in {1..3}; do
            result=$(measure_response_time "$model" "Write a Python hello world program" "test_$i")
            time=$(echo "$result" | cut -d',' -f2)
            tokens=$(echo "$result" | cut -d',' -f4)
            
            total_time=$(echo "$total_time + $time" | bc)
            if [[ "$tokens" != "N/A" ]]; then
                total_tokens=$(echo "$total_tokens + $tokens" | bc)
            fi
        done
        
        avg_time=$(echo "scale=2; $total_time / 3" | bc)
        avg_tokens=$(echo "scale=2; $total_tokens / 3" | bc)
        
        echo "$model,$avg_time,$avg_tokens" >> "$comparison_file"
    done
    
    print_header "Comparison Results"
    column -t -s ',' "$comparison_file"
}

# Main script logic
main() {
    check_ollama
    
    case "${1:-}" in
        compare)
            compare_models
            ;;
        *)
            if [[ -z "${1:-}" ]]; then
                # Interactive mode
                models=($(ollama list | tail -n +2 | awk '{print $1}'))
                
                print_header "Available Models"
                for i in "${!models[@]}"; do
                    echo "$((i+1))) ${models[$i]}"
                done
                
                read -p "Select model number: " model_num
                
                if [[ $model_num -ge 1 && $model_num -le ${#models[@]} ]]; then
                    run_benchmark "${models[$((model_num-1))]}"
                else
                    print_error "Invalid selection"
                    exit 1
                fi
            else
                # Direct model specification
                run_benchmark "$1"
            fi
            ;;
    esac
}

# Run main function
main "$@"