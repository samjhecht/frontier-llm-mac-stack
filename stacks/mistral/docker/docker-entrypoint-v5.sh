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
MAX_SEQS="${MISTRAL_MAX_SEQS:-16}"
MODEL_TYPE="${MISTRAL_MODEL_TYPE:-gguf}"
MODEL_ID="${MISTRAL_MODEL_ID:-}"
SERVE_IP="${MISTRAL_SERVE_IP:-0.0.0.0}"

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
echo "  Serve IP: $SERVE_IP"
echo "  Model Path: $MODEL_PATH"
echo "  Model Type: $MODEL_TYPE"
echo "  Log Level: $LOG_LEVEL"
echo "  Max Sequences: $MAX_SEQS"
[ -n "$MODEL_ID" ] && echo "  Model ID: $MODEL_ID"
echo ""

# Check if models directory exists and has models
if [ -d "$MODEL_PATH" ]; then
    MODEL_COUNT=$(find "$MODEL_PATH" -name "*.gguf" -o -name "*.safetensors" -o -name "*.bin" 2>/dev/null | wc -l)
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

# Build command based on model type
if [ "$MODEL_TYPE" = "gguf" ] && [ -n "$MODEL_ID" ]; then
    # For GGUF models with a specific model ID
    CMD_ARGS=(gguf --model-id "$MODEL_ID")
elif [ "$MODEL_TYPE" = "plain" ] && [ -n "$MODEL_ID" ]; then
    # For plain models
    CMD_ARGS=(plain --model-id "$MODEL_ID")
elif [ "$MODEL_TYPE" = "toml" ] && [ -f "$MODEL_PATH/config.toml" ]; then
    # For TOML configuration
    CMD_ARGS=(toml "$MODEL_PATH/config.toml")
else
    # Default to listing available options if no valid configuration
    echo "ERROR: No valid model configuration provided"
    echo "Please set MISTRAL_MODEL_TYPE and MISTRAL_MODEL_ID environment variables"
    echo ""
    echo "Example for GGUF model:"
    echo "  docker run -e MISTRAL_MODEL_TYPE=gguf -e MISTRAL_MODEL_ID=TheBloke/Mistral-7B-Instruct-v0.2-GGUF -v /path/to/models:/models frontier-mistral:metal-latest"
    echo ""
    echo "Available model types: plain, gguf, lora, x-lora, toml"
    exit 1
fi

# Add common options
CMD_ARGS+=(--port "$PORT")
CMD_ARGS+=(--serve-ip "$SERVE_IP")
CMD_ARGS+=(--max-seqs "$MAX_SEQS")

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