#!/bin/bash
# Dynamic Resource Calculator for Frontier LLM Stack
# Calculates optimal resource allocation based on available system resources

set -euo pipefail

# Get total system memory in GB
get_system_memory_gb() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        local mem_bytes=$(sysctl -n hw.memsize)
        echo $((mem_bytes / 1024 / 1024 / 1024))
    else
        # Linux
        local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        echo $((mem_kb / 1024 / 1024))
    fi
}

# Get available Docker memory in GB
get_docker_memory_gb() {
    if command -v docker >/dev/null 2>&1; then
        # Try to get Docker's memory limit
        local docker_mem=$(docker info 2>/dev/null | grep "Total Memory" | awk '{print $3}')
        if [ -n "$docker_mem" ]; then
            # Convert to GB (remove unit suffix)
            echo "${docker_mem%GiB}" | cut -d. -f1
        else
            # Fallback to system memory
            get_system_memory_gb
        fi
    else
        echo "0"
    fi
}

# Get CPU count
get_cpu_count() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sysctl -n hw.ncpu
    else
        nproc
    fi
}

# Calculate optimal memory allocation
calculate_memory_allocation() {
    local total_mem=$1
    local service=$2
    
    case "$service" in
        "mistral"|"ollama")
            # LLM service gets 60% of available memory
            echo $((total_mem * 60 / 100))
            ;;
        "monitoring")
            # Monitoring stack gets 10% (min 2GB, max 8GB)
            local mon_mem=$((total_mem * 10 / 100))
            [ $mon_mem -lt 2 ] && mon_mem=2
            [ $mon_mem -gt 8 ] && mon_mem=8
            echo $mon_mem
            ;;
        *)
            # Default: 50% of available
            echo $((total_mem * 50 / 100))
            ;;
    esac
}

# Main function
main() {
    echo "=== System Resource Analysis ==="
    
    local sys_mem=$(get_system_memory_gb)
    local docker_mem=$(get_docker_memory_gb)
    local cpu_count=$(get_cpu_count)
    
    echo "System Memory: ${sys_mem}GB"
    echo "Docker Memory: ${docker_mem}GB"
    echo "CPU Cores: ${cpu_count}"
    echo ""
    
    # Use Docker memory if available, otherwise system memory
    local available_mem=${docker_mem:-$sys_mem}
    
    if [ "$available_mem" -lt 16 ]; then
        echo "WARNING: Less than 16GB available. Minimum recommended is 32GB."
    fi
    
    echo "=== Recommended Resource Allocation ==="
    
    # Calculate allocations
    local llm_mem=$(calculate_memory_allocation $available_mem "mistral")
    local llm_mem_reservation=$((llm_mem * 75 / 100))  # 75% reservation
    local monitoring_mem=$(calculate_memory_allocation $available_mem "monitoring")
    
    echo ""
    echo "# Add these to your .env file:"
    echo ""
    echo "# LLM Service Resources"
    echo "MISTRAL_MEMORY_LIMIT=${llm_mem}g"
    echo "MISTRAL_MEMORY_RESERVATION=${llm_mem_reservation}g"
    echo "OLLAMA_MEMORY_LIMIT=${llm_mem}g"
    echo "OLLAMA_MEMORY_RESERVATION=${llm_mem_reservation}g"
    echo ""
    echo "# CPU Allocation"
    echo "MISTRAL_CPU_LIMIT=${cpu_count}"
    echo "OLLAMA_CPU_LIMIT=${cpu_count}"
    echo ""
    echo "# Monitoring Resources"
    echo "PROMETHEUS_MEMORY_LIMIT=${monitoring_mem}g"
    echo "GRAFANA_MEMORY_LIMIT=2g"
    echo ""
    echo "# Performance Tuning"
    echo "MISTRAL_NUM_THREADS=$((cpu_count - 2))"  # Leave 2 cores for system
    echo "OLLAMA_NUM_PARALLEL=$((cpu_count / 4))"  # Conservative parallel requests
    echo ""
    
    # Model recommendations based on memory
    echo "=== Model Recommendations ==="
    if [ "$llm_mem" -ge 64 ]; then
        echo "✓ Can run large models (30B+ parameters)"
        echo "  Recommended: qwen2.5-coder:32b, mixtral-8x7b"
    elif [ "$llm_mem" -ge 32 ]; then
        echo "✓ Can run medium models (13B-20B parameters)"
        echo "  Recommended: mistral-7b, codellama:13b"
    elif [ "$llm_mem" -ge 16 ]; then
        echo "✓ Can run small models (7B parameters)"
        echo "  Recommended: mistral-7b-instruct (quantized)"
    else
        echo "⚠ Limited to very small models"
        echo "  Consider upgrading Docker memory allocation"
    fi
}

# Run main function
main "$@"