#!/bin/bash
set -e

# Configuration defaults - make these configurable
readonly DEFAULT_PORT="${MISTRAL_PORT:-8080}"
readonly DEFAULT_MODEL_PATH="${MISTRAL_MODEL_PATH:-/models}"
readonly DEFAULT_LOG_LEVEL="${RUST_LOG:-info}"
readonly DEFAULT_MAX_SEQS="${MISTRAL_MAX_SEQS:-16}"
readonly DEFAULT_SERVE_IP="${MISTRAL_SERVE_IP:-0.0.0.0}"
readonly DEFAULT_SLEEP_DURATION="${MISTRAL_STARTUP_SLEEP:-2}"

# Parse command line arguments or use defaults
PORT="${PORT:-$DEFAULT_PORT}"
MODEL_PATH="${MODEL_PATH:-$DEFAULT_MODEL_PATH}"
LOG_LEVEL="${LOG_LEVEL:-$DEFAULT_LOG_LEVEL}"
MAX_SEQS="${MAX_SEQS:-$DEFAULT_MAX_SEQS}"
SERVE_IP="${SERVE_IP:-$DEFAULT_SERVE_IP}"

# Version-specific options
USE_V5_MODE="${MISTRAL_USE_V5_MODE:-true}"

# V5 specific options
MODEL_TYPE="${MISTRAL_MODEL_TYPE:-}"
MODEL_ID="${MISTRAL_MODEL_ID:-}"

# Legacy options (for backward compatibility)
NUM_THREADS="${MISTRAL_NUM_THREADS:-}"
CACHE_SIZE="${MISTRAL_CACHE_SIZE:-}"
TOKENIZER="${MISTRAL_TOKENIZER:-}"

# Set log level
export RUST_LOG="$LOG_LEVEL"

# Function to handle graceful shutdown
shutdown() {
    echo "Received shutdown signal, stopping mistralrs-server..."
    if [ -n "$SERVER_PID" ]; then
        kill -TERM "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID"
    fi
    exit 0
}

# Set up signal handlers
trap shutdown SIGTERM SIGINT

# Function to check model directory
check_model_directory() {
    local model_path="$1"
    
    if [ -d "$model_path" ]; then
        local model_count
        model_count=$(find "$model_path" -name "*.gguf" -o -name "*.safetensors" -o -name "*.bin" 2>/dev/null | wc -l)
        if [ "$model_count" -eq 0 ]; then
            echo "WARNING: No model files found in $model_path"
            echo "Please mount a volume with model files to $model_path"
        else
            echo "Found $model_count model file(s) in $model_path"
        fi
    else
        echo "WARNING: Model path $model_path does not exist"
        mkdir -p "$model_path"
    fi
}

# Function to validate model type
validate_model_type() {
    local model_type="$1"
    local valid_types=("plain" "gguf" "lora" "x-lora" "toml")
    
    for valid_type in "${valid_types[@]}"; do
        if [ "$model_type" = "$valid_type" ]; then
            return 0
        fi
    done
    
    echo "ERROR: Invalid MODEL_TYPE: $model_type"
    echo "Valid types are: ${valid_types[*]}"
    return 1
}

# Function to build V5 command arguments
build_v5_command() {
    local cmd_args=()
    
    # Validate model type if provided
    if [ -n "$MODEL_TYPE" ]; then
        if ! validate_model_type "$MODEL_TYPE"; then
            exit 1
        fi
    fi
    
    # Build command - global options come first, then command, then command-specific options
    cmd_args+=(--port "$PORT")
    cmd_args+=(--serve-ip "$SERVE_IP")
    cmd_args+=(--max-seqs "$MAX_SEQS")
    
    # Now add the model type and its specific options
    if [ "$MODEL_TYPE" = "gguf" ] && [ -n "$MODEL_ID" ]; then
        cmd_args+=(gguf --model-id "$MODEL_ID")
    elif [ "$MODEL_TYPE" = "plain" ] && [ -n "$MODEL_ID" ]; then
        cmd_args+=(plain --model-id "$MODEL_ID")
    elif [ "$MODEL_TYPE" = "lora" ] && [ -n "$MODEL_ID" ]; then
        cmd_args+=(lora --model-id "$MODEL_ID")
    elif [ "$MODEL_TYPE" = "x-lora" ] && [ -n "$MODEL_ID" ]; then
        cmd_args+=(x-lora --model-id "$MODEL_ID")
    elif [ "$MODEL_TYPE" = "toml" ] && [ -f "$MODEL_PATH/config.toml" ]; then
        cmd_args+=(toml "$MODEL_PATH/config.toml")
    else
        echo "ERROR: No valid model configuration provided"
        echo "Please set MISTRAL_MODEL_TYPE and MISTRAL_MODEL_ID environment variables"
        echo ""
        echo "Example for GGUF model:"
        echo "  docker run -e MISTRAL_MODEL_TYPE=gguf -e MISTRAL_MODEL_ID=TheBloke/Mistral-7B-Instruct-v0.2-GGUF -v /path/to/models:/models frontier-mistral:metal-latest"
        echo ""
        echo "Available model types: plain, gguf, lora, x-lora, toml"
        exit 1
    fi
    
    echo "${cmd_args[@]}"
}

# Function to build legacy command arguments
build_legacy_command() {
    local cmd_args=()
    
    cmd_args+=(--port "$PORT")
    cmd_args+=(--model-path "$MODEL_PATH")
    
    # Add optional arguments if set
    if [ -n "$NUM_THREADS" ]; then
        cmd_args+=(--num-threads "$NUM_THREADS")
    fi
    
    if [ -n "$CACHE_SIZE" ]; then
        cmd_args+=(--cache-size "$CACHE_SIZE")
    fi
    
    if [ -n "$MAX_SEQS" ]; then
        cmd_args+=(--max-seqs "$MAX_SEQS")
    fi
    
    if [ -n "$MODEL_ID" ]; then
        cmd_args+=(--model-id "$MODEL_ID")
    fi
    
    if [ -n "$TOKENIZER" ]; then
        cmd_args+=(--tokenizer "$TOKENIZER")
    fi
    
    echo "${cmd_args[@]}"
}

# Log startup information
echo "Starting mistralrs-server with:"
echo "  Port: $PORT"
echo "  Model Path: $MODEL_PATH"
echo "  Log Level: $LOG_LEVEL"
echo "  Max Sequences: $MAX_SEQS"
echo "  Mode: $([ "$USE_V5_MODE" = "true" ] && echo "V5" || echo "Legacy")"

if [ "$USE_V5_MODE" = "true" ]; then
    echo "  Serve IP: $SERVE_IP"
    [ -n "$MODEL_TYPE" ] && echo "  Model Type: $MODEL_TYPE"
    [ -n "$MODEL_ID" ] && echo "  Model ID: $MODEL_ID"
else
    [ -n "$NUM_THREADS" ] && echo "  Threads: $NUM_THREADS"
    [ -n "$CACHE_SIZE" ] && echo "  Cache Size: $CACHE_SIZE"
    [ -n "$MODEL_ID" ] && echo "  Model ID: $MODEL_ID"
    [ -n "$TOKENIZER" ] && echo "  Tokenizer: $TOKENIZER"
fi
echo ""

# Check model directory
check_model_directory "$MODEL_PATH"

# Build command arguments based on mode
if [ "$USE_V5_MODE" = "true" ]; then
    IFS=' ' read -ra CMD_ARGS <<< "$(build_v5_command)"
else
    IFS=' ' read -ra CMD_ARGS <<< "$(build_legacy_command)"
fi

# Start the server in the background
echo "Starting mistralrs-server..."
mistralrs-server "${CMD_ARGS[@]}" &
SERVER_PID=$!

# Wait for the server to start
sleep "$DEFAULT_SLEEP_DURATION"

# Check if server is running
if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "ERROR: mistralrs-server failed to start"
    exit 1
fi

echo "mistralrs-server started successfully (PID: $SERVER_PID)"

# Wait for the server process
wait "$SERVER_PID"