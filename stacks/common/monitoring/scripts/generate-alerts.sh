#!/bin/bash
# Script to generate alert configuration from templates with environment variables

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../config/prometheus/rules"

echo "Generating Prometheus alert rules from templates..."

# Process mistral-alerts.yml.template
if [ -f "$CONFIG_DIR/mistral-alerts.yml.template" ]; then
    echo "Processing mistral-alerts.yml.template..."
    
    # Set default values if not provided
    export MISTRAL_HIGH_ERROR_RATE_THRESHOLD_PCT="${MISTRAL_HIGH_ERROR_RATE_THRESHOLD_PCT:-5}"
    
    # Use envsubst to replace variables
    envsubst < "$CONFIG_DIR/mistral-alerts.yml.template" > "$CONFIG_DIR/mistral-alerts.yml"
    
    echo "Generated mistral-alerts.yml with the following thresholds:"
    echo "  - High latency: ${MISTRAL_HIGH_LATENCY_THRESHOLD:-5}s"
    echo "  - Very high latency: ${MISTRAL_VERY_HIGH_LATENCY_THRESHOLD:-10}s"
    echo "  - High error rate: ${MISTRAL_HIGH_ERROR_RATE_THRESHOLD_PCT:-5}%"
    echo "  - High active requests: ${MISTRAL_HIGH_ACTIVE_REQUESTS_THRESHOLD:-50}"
    echo "  - Slow generation: ${MISTRAL_SLOW_GENERATION_THRESHOLD:-30}s"
fi

echo "Alert generation complete!"