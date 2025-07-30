# Step 16: Documentation and Troubleshooting Guide

## Overview
Create comprehensive documentation and troubleshooting guides to ensure smooth operation and maintenance of the LLM stack. This includes user guides, API documentation, and common issue resolution.

## Tasks
1. Create user documentation
2. Develop API reference guide
3. Build troubleshooting database
4. Create runbooks for common operations
5. Implement documentation automation

## Implementation Details

### 1. User Documentation Structure
Create `docs/user-guide.md`:
```markdown
# Frontier LLM Stack User Guide

## Table of Contents
1. [Getting Started](#getting-started)
2. [Using Aider](#using-aider)
3. [API Usage](#api-usage)
4. [Monitoring](#monitoring)
5. [Best Practices](#best-practices)

## Getting Started

### Accessing the LLM Stack
- **Ollama API**: http://mac-studio.local:11434
- **Grafana Dashboard**: http://mac-studio.local:3000
- **Health Check**: http://mac-studio.local/health

### Quick Test
\`\`\`bash
# Test API connection
curl http://mac-studio.local:11434/api/version

# Generate text
curl -X POST http://mac-studio.local:11434/api/generate \
  -d '{"model": "qwen2.5-coder:32b-instruct-q8_0", "prompt": "Hello, world!"}'
\`\`\`

## Using Aider

### Basic Commands
\`\`\`bash
# Start Aider in a project
cd my-project
aider

# Work on specific files
aider src/main.py src/utils.py

# Use specific model
aider --model ollama/qwen2.5-coder:32b-instruct-q8_0
\`\`\`

### Aider Best Practices
1. Always work in a git repository
2. Review changes before committing
3. Use clear, specific prompts
4. Break large tasks into steps
```

### 2. API Reference
Create `docs/api-reference.md`:
```markdown
# Ollama API Reference

## Base URL
\`http://mac-studio.local:11434/api\`

## Endpoints

### Generate Text
\`POST /api/generate\`

**Request:**
\`\`\`json
{
  "model": "qwen2.5-coder:32b-instruct-q8_0",
  "prompt": "Write a Python function",
  "stream": false,
  "options": {
    "temperature": 0.7,
    "top_p": 0.9,
    "num_predict": 200
  }
}
\`\`\`

**Response:**
\`\`\`json
{
  "model": "qwen2.5-coder:32b-instruct-q8_0",
  "response": "def example_function():\n    ...",
  "done": true,
  "context": [1, 2, 3],
  "total_duration": 5000000000,
  "eval_count": 150
}
\`\`\`

### List Models
\`GET /api/tags\`

### Model Info
\`POST /api/show\`
```

### 3. Troubleshooting Database
Create `scripts/docs/generate-troubleshooting.sh`:
```bash
#!/bin/bash
set -euo pipefail

# Generate troubleshooting guide from common issues
cat > docs/troubleshooting.md << 'EOF'
# Troubleshooting Guide

## Common Issues and Solutions

### 1. Ollama Not Responding
**Symptoms:** API calls timeout, no response from service

**Diagnosis:**
\`\`\`bash
# Check if service is running
docker compose ps ollama

# Check logs
docker compose logs --tail=50 ollama

# Test local connection
docker compose exec ollama curl http://localhost:11434/api/version
\`\`\`

**Solutions:**
1. Restart the service: `docker compose restart ollama`
2. Check memory usage: `docker stats ollama`
3. Verify model is loaded: `docker compose exec ollama ollama list`

### 2. Slow Response Times
**Symptoms:** Generation takes >30 seconds for simple prompts

**Diagnosis:**
\`\`\`bash
# Check resource usage
docker stats

# Monitor GPU usage (if available)
sudo powermetrics --samplers gpu_power -n 1

# Check for thermal throttling
sudo pmset -g thermlog
\`\`\`

**Solutions:**
1. Reduce concurrent requests
2. Use smaller quantization (Q4 instead of Q8)
3. Increase Docker memory allocation
4. Check for background processes

### 3. Connection Refused from MacBook Pro
**Symptoms:** Cannot connect to Mac Studio services

**Diagnosis:**
\`\`\`bash
# Test network connectivity
ping mac-studio.local

# Check firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --listapps

# Verify service binding
netstat -an | grep 11434
\`\`\`

**Solutions:**
1. Verify services bound to 0.0.0.0, not 127.0.0.1
2. Check firewall allows Docker
3. Use IP address instead of hostname
4. Verify same network subnet

### 4. Model Loading Failures
**Symptoms:** "Model not found" or loading errors

**Diagnosis:**
\`\`\`bash
# Check available space
df -h ~/ollama-models

# Verify model files
docker compose exec ollama ls -la /root/.ollama/models

# Check permissions
ls -la ~/ollama-models
\`\`\`

**Solutions:**
1. Re-pull the model
2. Clear cache and retry
3. Check disk space (need 2x model size)
4. Verify model name spelling

### 5. High Memory Usage
**Symptoms:** System becomes unresponsive, swapping

**Diagnosis:**
\`\`\`bash
# Check memory pressure
vm_stat

# Monitor swap usage
sysctl vm.swapusage

# Check Docker limits
docker compose exec ollama cat /proc/meminfo
\`\`\`

**Solutions:**
1. Reduce Docker memory limits
2. Use smaller models
3. Limit concurrent model loads
4. Enable model unloading
EOF

echo "✓ Troubleshooting guide generated"
```

### 4. Operational Runbooks
Create `docs/runbooks/` directory with operational procedures:

#### Daily Operations (`docs/runbooks/daily-operations.md`):
```markdown
# Daily Operations Runbook

## Morning Checklist
1. [ ] Check service health
   ```bash
   ./scripts/health-check.sh
   ```

2. [ ] Review overnight alerts
   - Check Grafana alerts
   - Review logs for errors

3. [ ] Verify backup completed
   ```bash
   ls -la /Volumes/Backup/frontier-llm/
   ```

4. [ ] Check resource usage trends
   - Memory usage < 80%
   - Disk space > 20% free
   - No thermal throttling

## End of Day
1. [ ] Run integration tests
2. [ ] Check tomorrow's schedule
3. [ ] Verify backups are current
```

#### Emergency Response (`docs/runbooks/emergency-response.md`):
```markdown
# Emergency Response Procedures

## Service Down
1. **Assess Impact**
   - Which services affected?
   - How many users impacted?

2. **Immediate Actions**
   ```bash
   # Restart all services
   docker compose down
   docker compose up -d
   
   # Check status
   docker compose ps
   ```

3. **If Restart Fails**
   - Check logs: `docker compose logs`
   - Verify disk space
   - Check for corrupted files
   - Consider restore from backup

## Performance Crisis
1. **Identify Bottleneck**
   - CPU, Memory, or I/O?
   - Single service or system-wide?

2. **Emergency Mitigation**
   - Reduce concurrent users
   - Switch to smaller model
   - Disable non-critical services
```

### 5. Documentation Automation
Create `scripts/docs/update-docs.sh`:
```bash
#!/bin/bash
set -euo pipefail

echo "=== Updating Documentation ==="

# Generate current configuration docs
echo "## Current Configuration" > docs/current-config.md
echo "Generated: $(date)" >> docs/current-config.md
echo "" >> docs/current-config.md

# Document Docker services
echo "### Docker Services" >> docs/current-config.md
docker compose ps --format table >> docs/current-config.md

# Document models
echo -e "\n### Available Models" >> docs/current-config.md
docker compose exec ollama ollama list >> docs/current-config.md

# Document environment
echo -e "\n### Environment Variables" >> docs/current-config.md
grep -v '^#' .env | grep -v '^$' | sed 's/=.*/=***/' >> docs/current-config.md

# Generate API examples from recent usage
echo -e "\n## Recent API Usage Examples" > docs/api-examples.md
docker compose logs nginx | grep "POST /api" | tail -20 | \
    awk '{print $8}' | sort | uniq -c | sort -rn >> docs/api-examples.md

# Create quick reference card
cat > docs/quick-reference.md << 'EOF'
# Quick Reference

## Essential Commands
| Action | Command |
|--------|---------|
| Start all services | `docker compose up -d` |
| Stop all services | `docker compose down` |
| View logs | `docker compose logs -f [service]` |
| List models | `docker compose exec ollama ollama list` |
| Pull new model | `./pull-model.sh [model-name]` |
| Run backup | `./scripts/backup/backup-llm-stack.sh` |
| Check health | `curl http://localhost/health` |

## Key URLs
- Ollama API: http://mac-studio.local:11434
- Grafana: http://mac-studio.local:3000
- Prometheus: http://mac-studio.local:9090

## Support Contacts
- GitHub Issues: https://github.com/your-org/frontier-llm-stack
- Team Chat: #llm-support
EOF

echo "✓ Documentation updated"
```

### 6. Interactive Troubleshooter
Create `scripts/troubleshoot.sh`:
```bash
#!/bin/bash
set -euo pipefail

echo "=== Frontier LLM Stack Troubleshooter ==="
echo "This will help diagnose common issues"
echo

PS3="Select an issue category: "
options=("Connection Problems" "Performance Issues" "Model Errors" "Service Failures" "Exit")

select opt in "${options[@]}"; do
    case $opt in
        "Connection Problems")
            echo "Checking connectivity..."
            ./scripts/testing/test-remote-connectivity.sh
            ;;
        "Performance Issues")
            echo "Running performance diagnostics..."
            docker stats --no-stream
            ./scripts/optimization/performance-test.sh
            ;;
        "Model Errors")
            echo "Checking model status..."
            docker compose exec ollama ollama list
            docker compose logs --tail=50 ollama | grep -i error
            ;;
        "Service Failures")
            echo "Checking service health..."
            docker compose ps
            ./scripts/health-check.sh
            ;;
        "Exit")
            break
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
done
```

## Dependencies
- All previous steps completed
- System operational

## Success Criteria
- Comprehensive user documentation exists
- API fully documented with examples
- Common issues have solutions documented
- Runbooks cover all operations
- Documentation stays current automatically

## Testing
```bash
# Generate all documentation
./scripts/docs/update-docs.sh

# Test troubleshooter
./scripts/troubleshoot.sh

# Verify documentation completeness
find docs -name "*.md" -exec echo "Found: {}" \;
```

## Notes
- Keep documentation in version control
- Update docs with each major change
- Include real examples from usage
- Regular review and updates needed