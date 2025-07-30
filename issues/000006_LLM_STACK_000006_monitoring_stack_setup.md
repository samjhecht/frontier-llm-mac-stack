# Step 6: Monitoring Stack Setup (Prometheus/Grafana)

## Overview
Deploy and configure the monitoring stack consisting of Prometheus for metrics collection, Grafana for visualization, and Node Exporter for system metrics. This provides observability into the LLM stack performance.

## Tasks
1. Deploy Prometheus with Ollama scrape configuration
2. Deploy Grafana with pre-configured dashboards
3. Deploy Node Exporter for system metrics
4. Configure datasources and import dashboards
5. Set up basic alerts

## Implementation Details

### 1. Deploy Monitoring Services
```bash
# Start monitoring stack
docker compose up -d prometheus grafana node-exporter
```

### 2. Prometheus Configuration
Already configured in `config/prometheus/prometheus.yml`:
- Ollama metrics endpoint
- Node exporter metrics
- 15-second scrape interval

### 3. Grafana Dashboard Creation
Create enhanced Ollama dashboard at `config/grafana/dashboards/ollama-enhanced.json`:
```json
{
  "dashboard": {
    "title": "Ollama LLM Performance",
    "panels": [
      // Request rate panel
      // Response time histogram
      // Token generation speed
      // Model memory usage
      // Queue depth
      // Error rate
    ]
  }
}
```

### 4. Alert Rules
Create `config/prometheus/alerts.yml`:
```yaml
groups:
  - name: ollama_alerts
    rules:
      - alert: OllamaHighResponseTime
        expr: ollama_request_duration_seconds > 30
        for: 5m
      - alert: OllamaQueueBacklog
        expr: ollama_queue_depth > 10
        for: 10m
```

### 5. Dashboard Import Script
```bash
# Import dashboards via API
curl -X POST http://admin:frontier-llm@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @config/grafana/dashboards/ollama-enhanced.json
```

## Dependencies
- Step 5: Ollama service running
- Network connectivity between services

## Success Criteria
- All monitoring services running
- Prometheus scraping metrics successfully
- Grafana accessible at http://localhost:3000
- Default dashboards imported
- Ollama metrics visible in Grafana

## Testing
- Access Grafana UI (admin/frontier-llm)
- Check Prometheus targets at http://localhost:9090/targets
- Verify metrics collection
- Test dashboard data population

## Notes
- First metrics may take 1-2 minutes to appear
- Default retention is 15 days
- Consider disk space for metrics storage