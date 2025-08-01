# MISTRAL_000006: Integrate Mistral.rs with Monitoring Stack

## Objective
Configure Prometheus to scrape metrics from Mistral.rs and create Grafana dashboards for monitoring inference performance.

## Context
Mistral.rs needs to expose metrics in a format that Prometheus can scrape. We need to configure the monitoring stack to collect and visualize these metrics alongside the Ollama metrics.

## Tasks

### 1. Enable Metrics in Mistral.rs
- Configure Mistral.rs to expose Prometheus metrics
- Set up metrics endpoint (typically /metrics)
- Ensure key metrics are exposed:
  - Request latency
  - Token generation rate
  - Model loading time
  - Memory usage
  - Queue depth

### 2. Configure Prometheus Scraping
- Add Mistral.rs target to Prometheus configuration
- Set up appropriate scrape intervals
- Configure metric relabeling if needed
- Test metric collection

### 3. Create Grafana Dashboards
- Design Mistral.rs specific dashboard
- Include key performance indicators:
  - Requests per second
  - Average latency
  - Token throughput
  - Resource utilization
- Add comparative views with Ollama metrics

### 4. Set Up Alerts
- Define alerting rules for Mistral.rs
- Configure high latency alerts
- Set up resource exhaustion warnings
- Integrate with existing alert channels

## Implementation Details

```yaml
# stacks/common/monitoring/prometheus/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  # Existing configs...
  
  - job_name: 'mistral'
    static_configs:
      - targets: ['mistral:9090']
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        replacement: 'mistral-inference'

# Grafana Dashboard JSON snippet
{
  "panels": [
    {
      "title": "Inference Request Rate",
      "targets": [
        {
          "expr": "rate(mistral_http_requests_total[5m])",
          "legendFormat": "Mistral.rs"
        },
        {
          "expr": "rate(ollama_http_requests_total[5m])",
          "legendFormat": "Ollama"
        }
      ]
    }
  ]
}
```

## Success Criteria
- Prometheus successfully scrapes Mistral.rs metrics
- Grafana dashboards display real-time performance data
- Alerts fire appropriately for defined conditions
- Monitoring parity with Ollama stack

## Estimated Changes
- ~50 lines of Prometheus configuration
- ~500 lines of Grafana dashboard JSON
- ~30 lines of alerting rules