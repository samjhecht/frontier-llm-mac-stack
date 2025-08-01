# MISTRAL_000002: Extract Common Monitoring Components

## Objective
Extract monitoring components (Prometheus, Grafana, Node Exporter) into a shared configuration that can be used by both Ollama and Mistral.rs stacks.

## Context
Both inference engines will use the same monitoring infrastructure. We need to separate these components so they can be shared without duplication.

## Tasks

### 1. Create Common Docker Compose Fragment
- Create `stacks/common/docker-compose.monitoring.yml`
- Extract Prometheus, Grafana, and Node Exporter service definitions
- Define shared volumes and networks

### 2. Create Monitoring Configuration Templates
- Set up `stacks/common/monitoring/prometheus/prometheus.yml` template
- Create scrape configurations for both Ollama and Mistral.rs endpoints
- Set up conditional target inclusion based on active stack

### 3. Update Grafana Dashboards
- Create generic inference engine dashboard template
- Add variables for switching between different metric sources
- Ensure dashboards work with both Ollama and Mistral.rs metrics

### 4. Create Monitoring Start/Stop Scripts
- Create `scripts/monitoring-start.sh` and `scripts/monitoring-stop.sh`
- Ensure monitoring can run independently of inference engines
- Add health checks for monitoring stack

## Implementation Details

```yaml
# stacks/common/docker-compose.monitoring.yml
version: '3.8'

services:
  prometheus:
    # ... existing prometheus config
    volumes:
      - ./monitoring/prometheus:/etc/prometheus
      - prometheus-data:/prometheus
    networks:
      - frontier-monitoring

  grafana:
    # ... existing grafana config
    volumes:
      - ./monitoring/grafana/provisioning:/etc/grafana/provisioning
      - grafana-data:/var/lib/grafana
    networks:
      - frontier-monitoring
      
networks:
  frontier-monitoring:
    external: true
```

## Success Criteria
- Monitoring stack can run independently
- Both Ollama and Mistral.rs can be monitored without configuration duplication
- Grafana dashboards automatically adapt to active inference engine
- Clean separation of concerns

## Estimated Changes
- ~200 lines of Docker Compose configuration
- ~100 lines of Prometheus configuration
- Dashboard template updates