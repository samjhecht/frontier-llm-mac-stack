#!/bin/bash
# Common HTTP utility functions for testing

# Source test-utils if not already sourced
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -z "${print_info:-}" ]; then
    source "$SCRIPT_DIR/test-utils.sh"
fi

# HTTP POST request with retry
http_post_with_retry() {
    local url=$1
    local data=$2
    local max_retries=${3:-3}
    local timeout=${4:-30}
    
    retry_with_backoff "$max_retries" 1 10 \
        curl -s -f -X POST "$url" \
            -H "Content-Type: application/json" \
            --max-time "$timeout" \
            -d "$data"
}

# Test API endpoint availability
test_api_endpoint() {
    local url=$1
    local expected_status=${2:-200}
    
    local response_code=$(curl -s -o /dev/null -w "%{http_code}" "$url")
    
    if [ "$response_code" = "$expected_status" ]; then
        return 0
    else
        return 1
    fi
}

# Make chat completion request
make_chat_request() {
    local url=$1
    local model=$2
    local prompt=$3
    local max_tokens=${4:-100}
    local stream=${5:-false}
    
    local data=$(cat <<EOF
{
    "model": "$model",
    "messages": [{"role": "user", "content": "$prompt"}],
    "max_tokens": $max_tokens,
    "stream": $stream
}
EOF
    )
    
    http_post_with_retry "$url/v1/chat/completions" "$data"
}

# Make generate request (Ollama format)
make_generate_request() {
    local url=$1
    local model=$2
    local prompt=$3
    local max_tokens=${4:-100}
    local stream=${5:-false}
    
    local data=$(cat <<EOF
{
    "model": "$model",
    "prompt": "$prompt",
    "max_tokens": $max_tokens,
    "stream": $stream
}
EOF
    )
    
    http_post_with_retry "$url/api/generate" "$data"
}

# Check model availability
check_model_available() {
    local url=$1
    local model=$2
    
    # Try OpenAI-style endpoint first
    local response=$(curl -s "$url/v1/models" 2>/dev/null || echo "{}")
    
    if echo "$response" | jq -e ".data[] | select(.id == \"$model\")" > /dev/null 2>&1; then
        return 0
    fi
    
    # Try Ollama-style endpoint
    response=$(curl -s "$url/api/tags" 2>/dev/null || echo "{}")
    
    if echo "$response" | jq -e ".models[] | select(.name == \"$model\")" > /dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

# Measure response time
measure_response_time() {
    local url=$1
    local data=$2
    
    local start_time=$(date +%s.%N)
    
    if curl -s -X POST "$url" \
        -H "Content-Type: application/json" \
        -d "$data" > /dev/null 2>&1; then
        
        local end_time=$(date +%s.%N)
        echo "$end_time - $start_time" | bc
    else
        echo "-1"
    fi
}

# Stream response test
test_streaming_response() {
    local url=$1
    local model=$2
    local prompt=$3
    
    local tmpfile=$(mktemp)
    local chunks=0
    
    # Start streaming request
    curl -s -N -X POST "$url/api/generate" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$model\",
            \"prompt\": \"$prompt\",
            \"stream\": true
        }" 2>/dev/null | while IFS= read -r line; do
        echo "$line" >> "$tmpfile"
        ((chunks++))
        
        # Stop after receiving some chunks
        if [ $chunks -ge 5 ]; then
            break
        fi
    done
    
    local result=1
    if [ -s "$tmpfile" ] && [ $chunks -gt 0 ]; then
        result=0
    fi
    
    rm -f "$tmpfile"
    return $result
}

# Validate JSON response
validate_json_response() {
    local response=$1
    
    if echo "$response" | jq empty 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Extract response content
extract_response_content() {
    local response=$1
    local api_type=${2:-"openai"}  # "openai" or "ollama"
    
    if [ "$api_type" = "openai" ]; then
        echo "$response" | jq -r '.choices[0].message.content // empty' 2>/dev/null
    else
        echo "$response" | jq -r '.response // empty' 2>/dev/null
    fi
}