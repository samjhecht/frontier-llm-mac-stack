# Monitoring Stack Troubleshooting Guide

## Common Issues and Solutions

### 1. Services Fail to Start

#### Port Conflicts
**Symptom**: Error message about port already in use

**Solution**:
```bash
# Check what's using the ports
lsof -i :9090  # Prometheus
lsof -i :3000  # Grafana
lsof -i :9100  # Node Exporter
lsof -i :9400  # NVIDIA GPU Exporter

# Either stop the conflicting service or use different ports:
export FRONTIER_PROMETHEUS_PORT=19090
export FRONTIER_GRAFANA_PORT=13000
./monitoring-start.sh
```

#### Docker Network Issues
**Symptom**: Network frontier-llm-network not found

**Solution**:
```bash
# Create the network manually
docker network create frontier-llm-network

# Or use a different network
export FRONTIER_NETWORK_NAME=my-custom-network
./monitoring-start.sh
```

### 2. Prometheus Configuration Errors

**Symptom**: Prometheus configuration validation fails

**Solution**:
```bash
# Check the configuration manually
docker run --rm -v "$PWD/stacks/common/monitoring/config/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro" \
  prom/prometheus:latest promtool check config /etc/prometheus/prometheus.yml

# Common issues:
# - Invalid YAML syntax
# - Incorrect indentation
# - Missing required fields
```

### 3. Grafana Login Issues

**Symptom**: Cannot login to Grafana

**Solution**:
- Default credentials: admin/changeme
- If you changed the password and forgot it:
  ```bash
  # Reset Grafana admin password
  docker exec -it frontier-grafana grafana cli admin reset-admin-password newpassword
  ```

### 4. Missing Metrics

#### Inference Engine Metrics Not Showing
**Symptom**: Ollama/Mistral metrics not appearing in Prometheus

**Solution**:
- Verify the inference engines are running:
  ```bash
  docker ps | grep -E "ollama|mistral"
  ```
- Check if metrics endpoints are accessible:
  ```bash
  curl http://localhost:11434/api/metrics  # Ollama
  curl http://localhost:11434/metrics      # Mistral
  ```
- The monitoring stack handles missing inference engines gracefully, but metrics won't be available unless the engines are running

#### GPU Metrics Not Available
**Symptom**: No GPU metrics in dashboard

**Solution**:
- Verify NVIDIA drivers and nvidia-docker runtime:
  ```bash
  nvidia-smi
  docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi
  ```
- Check if nvidia-exporter is running:
  ```bash
  docker ps | grep nvidia-exporter
  ```

### 5. Health Check Failures

**Symptom**: Services show as unhealthy during startup

**Solution**:
- Check container logs:
  ```bash
  docker logs frontier-prometheus
  docker logs frontier-grafana
  docker logs frontier-node-exporter
  ```
- Verify HTTP endpoints manually:
  ```bash
  curl http://localhost:9090/-/healthy   # Prometheus
  curl http://localhost:3000/api/health  # Grafana
  curl http://localhost:9100/metrics     # Node Exporter
  ```

### 6. Data Persistence Issues

**Symptom**: Lost dashboards or metrics after restart

**Solution**:
- Ensure volumes are properly mounted:
  ```bash
  docker volume ls | grep -E "prometheus-data|grafana-data"
  ```
- Check volume permissions:
  ```bash
  docker exec -it frontier-prometheus ls -la /prometheus
  docker exec -it frontier-grafana ls -la /var/lib/grafana
  ```

### 7. Container Name Conflicts

**Symptom**: Container name already in use

**Solution**:
```bash
# Remove old containers
docker rm -f frontier-prometheus frontier-grafana frontier-node-exporter

# Or use a different prefix
export FRONTIER_CONTAINER_PREFIX=myproject-
./monitoring-start.sh
```

## Debugging Commands

### View All Logs
```bash
# View logs for all monitoring services
docker-compose -f stacks/common/monitoring/docker-compose.yml logs -f

# View logs for specific service
docker logs -f frontier-prometheus
```

### Check Service Status
```bash
# List all monitoring containers
docker ps --filter "name=frontier-"

# Check detailed container status
docker inspect frontier-prometheus | jq '.[0].State'
```

### Test Connectivity
```bash
# Test network connectivity between containers
docker exec -it frontier-prometheus ping -c 3 frontier-grafana
docker exec -it frontier-prometheus wget -O- http://frontier-node-exporter:9100/metrics
```

### Clean Start
```bash
# Stop everything and clean up
./monitoring-stop.sh
docker volume rm frontier-llm-mac-stack_prometheus-data frontier-llm-mac-stack_grafana-data
./monitoring-start.sh
```

## Getting Help

If you continue to experience issues:

1. Check container logs for specific error messages
2. Verify all prerequisites are installed (Docker, docker-compose)
3. Ensure Docker daemon is running and accessible
4. Check system resources (disk space, memory)
5. Review the monitoring configuration files for syntax errors