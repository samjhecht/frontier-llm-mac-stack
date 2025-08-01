#!/bin/bash
set -e

# Default values
DEFAULT_PORT="${MISTRAL_PORT:-11434}"
DEFAULT_MODEL_PATH="${MISTRAL_MODEL_PATH:-/models}"
DEFAULT_LOG_LEVEL="${RUST_LOG:-info}"

# Parse command line arguments or use defaults
PORT="${PORT:-$DEFAULT_PORT}"
MODEL_PATH="${MODEL_PATH:-$DEFAULT_MODEL_PATH}"
LOG_LEVEL="${LOG_LEVEL:-$DEFAULT_LOG_LEVEL}"

# Additional mistral.rs specific options
MAX_SEQS="${MISTRAL_MAX_SEQS:-10}"
NUM_THREADS="${MISTRAL_NUM_THREADS:-}"
CACHE_SIZE="${MISTRAL_CACHE_SIZE:-}"
MODEL_ID="${MISTRAL_MODEL_ID:-}"
TOKENIZER="${MISTRAL_TOKENIZER:-}"

# Build command arguments
CMD_ARGS=("--port" "$PORT")
CMD_ARGS+=("--model-path" "$MODEL_PATH")

# Add optional arguments if set
if [ -n "$NUM_THREADS" ]; then
    CMD_ARGS+=("--num-threads" "$NUM_THREADS")
fi

if [ -n "$CACHE_SIZE" ]; then
    CMD_ARGS+=("--cache-size" "$CACHE_SIZE")
fi

if [ -n "$MAX_SEQS" ]; then
    CMD_ARGS+=("--max-seqs" "$MAX_SEQS")
fi

if [ -n "$MODEL_ID" ]; then
    CMD_ARGS+=("--model-id" "$MODEL_ID")
fi

if [ -n "$TOKENIZER" ]; then
    CMD_ARGS+=("--tokenizer" "$TOKENIZER")
fi

# Set log level
export RUST_LOG="$LOG_LEVEL"

# Function to handle graceful shutdown
shutdown() {
    echo "Received shutdown signal, stopping mistralrs-server..."
    kill -TERM "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID"
    exit 0
}

# Set up signal handlers
trap shutdown SIGTERM SIGINT

# Log startup information
echo "Starting mistralrs-server with:"
echo "  Port: $PORT"
echo "  Model Path: $MODEL_PATH"
echo "  Log Level: $LOG_LEVEL"
echo "  Max Sequences: $MAX_SEQS"
[ -n "$NUM_THREADS" ] && echo "  Threads: $NUM_THREADS"
[ -n "$CACHE_SIZE" ] && echo "  Cache Size: $CACHE_SIZE"
[ -n "$MODEL_ID" ] && echo "  Model ID: $MODEL_ID"
[ -n "$TOKENIZER" ] && echo "  Tokenizer: $TOKENIZER"
echo ""

# Check if models directory exists and has models
if [ -d "$MODEL_PATH" ]; then
    MODEL_COUNT=$(find "$MODEL_PATH" -name "*.gguf" -o -name "*.safetensors" -o -name "*.bin" | wc -l)
    if [ "$MODEL_COUNT" -eq 0 ]; then
        echo "WARNING: No model files found in $MODEL_PATH"
        echo "Please mount a volume with model files to $MODEL_PATH"
    else
        echo "Found $MODEL_COUNT model file(s) in $MODEL_PATH"
    fi
else
    echo "WARNING: Model path $MODEL_PATH does not exist"
    mkdir -p "$MODEL_PATH"
fi

# Start the server in the background
echo "Starting mistralrs-server..."
mistralrs-server "${CMD_ARGS[@]}" &
SERVER_PID=$!

# Wait for the server to start
sleep 2

# Check if server is running
if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "ERROR: mistralrs-server failed to start"
    exit 1
fi

echo "mistralrs-server started successfully (PID: $SERVER_PID)"

# Wait for the server process
wait "$SERVER_PID"