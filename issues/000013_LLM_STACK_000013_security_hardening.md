# Step 13: Security Hardening

## Overview
Implement comprehensive security measures to protect the LLM stack from unauthorized access and potential vulnerabilities. Focus on network security, authentication, and monitoring.

## Tasks
1. Implement network access controls
2. Add authentication to Ollama API
3. Set up SSL/TLS encryption
4. Configure firewall rules
5. Implement security monitoring and alerts

## Implementation Details

### 1. Network Access Control
Create `config/nginx/security.conf`:
```nginx
# IP whitelisting for local network only
geo $allowed_network {
    default 0;
    192.168.0.0/16 1;
    10.0.0.0/8 1;
    172.16.0.0/12 1;
    127.0.0.1 1;
    ::1 1;
}

map $allowed_network $denied {
    0 1;
    1 0;
}

# Rate limiting zones
limit_req_zone $binary_remote_addr zone=api_strict:10m rate=5r/s;
limit_req_zone $binary_remote_addr zone=api_burst:10m rate=30r/m;
limit_conn_zone $binary_remote_addr zone=conn_limit:10m;

# Request size limits
client_max_body_size 10m;
client_body_buffer_size 128k;
```

### 2. API Authentication
Create `scripts/security/setup-api-auth.sh`:
```bash
#!/bin/bash
set -euo pipefail

# Generate API keys
echo "=== Setting up API Authentication ==="

# Generate secure API key
API_KEY=$(openssl rand -hex 32)
echo "Generated API key: $API_KEY"

# Create htpasswd file for basic auth
htpasswd -cb config/nginx/.htpasswd ollama-user "$API_KEY"

# Update Nginx config for auth
cat > config/nginx/api-auth.conf << 'EOF'
# API Authentication
location /api/ {
    # Network access control
    if ($denied) {
        return 403 "Access denied";
    }
    
    # Basic authentication
    auth_basic "Ollama API";
    auth_basic_user_file /etc/nginx/.htpasswd;
    
    # Rate limiting
    limit_req zone=api_strict burst=10 nodelay;
    limit_conn conn_limit 10;
    
    # Security headers
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000" always;
    
    # Proxy to Ollama
    proxy_pass http://ollama;
    proxy_set_header Authorization "";  # Don't forward auth to Ollama
}
EOF

# Store API key securely
echo "$API_KEY" > config/.api-key
chmod 600 config/.api-key
```

### 3. SSL/TLS Setup
Create `scripts/security/setup-ssl.sh`:
```bash
#!/bin/bash
set -euo pipefail

echo "=== Setting up SSL/TLS ==="

SSL_DIR="./config/ssl"
mkdir -p "$SSL_DIR"

# Generate self-signed certificate for local use
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$SSL_DIR/key.pem" \
    -out "$SSL_DIR/cert.pem" \
    -subj "/C=US/ST=State/L=City/O=FrontierLLM/CN=mac-studio.local" \
    -addext "subjectAltName=DNS:mac-studio.local,DNS:localhost,IP:127.0.0.1"

# Update Nginx for HTTPS
cat > config/nginx/ssl.conf << 'EOF'
server {
    listen 443 ssl http2;
    server_name mac-studio.local localhost;
    
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    
    # Modern SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;
    
    # SSL session caching
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Include all location blocks from default.conf
    include /etc/nginx/conf.d/api-auth.conf;
    include /etc/nginx/conf.d/security.conf;
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name mac-studio.local localhost;
    return 301 https://$server_name$request_uri;
}
EOF

echo "✓ SSL certificate generated"
echo "✓ HTTPS configured on port 443"
```

### 4. Firewall Configuration
Create `scripts/security/configure-firewall.sh`:
```bash
#!/bin/bash
set -euo pipefail

echo "=== Configuring macOS Firewall ==="

# Enable firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

# Allow specific applications
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /Applications/Docker.app
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /Applications/Docker.app

# Configure Docker port access
# Note: macOS firewall works at application level, not port level
# For port-level control, use Docker's built-in networking

echo "✓ Firewall configured"
echo "Note: Fine-grained port control managed by Docker networks"
```

### 5. Security Monitoring
Create `config/prometheus/security-alerts.yml`:
```yaml
groups:
  - name: security
    interval: 30s
    rules:
      - alert: UnauthorizedAPIAccess
        expr: |
          rate(nginx_http_requests_total{status="403"}[5m]) > 0.1
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Unauthorized API access attempts detected"
          description: "{{ $value }} unauthorized requests per second"
      
      - alert: HighAPIUsage
        expr: |
          rate(nginx_http_requests_total{location="/api/"}[5m]) > 100
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Unusually high API usage"
          description: "{{ $value }} requests per second to API"
      
      - alert: SSLCertificateExpiring
        expr: |
          nginx_ssl_certificate_expiry_seconds < 7 * 24 * 3600
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "SSL certificate expiring soon"
          description: "Certificate expires in {{ $value | humanizeDuration }}"
```

### 6. Security Audit Script
Create `scripts/security/security-audit.sh`:
```bash
#!/bin/bash
set -euo pipefail

echo "=== Security Audit ==="

# Check network exposure
echo "1. Network Exposure:"
netstat -an | grep LISTEN | grep -E "11434|3000|9090|80|443" || true

# Check Docker network settings
echo -e "\n2. Docker Network Configuration:"
docker network inspect frontier-llm-network | jq '.[0].Options'

# Check file permissions
echo -e "\n3. Sensitive File Permissions:"
ls -la config/.api-key config/ssl/*.pem 2>/dev/null || echo "No sensitive files found"

# Check authentication
echo -e "\n4. Authentication Status:"
if [[ -f config/nginx/.htpasswd ]]; then
    echo "✓ API authentication configured"
else
    echo "✗ API authentication not configured"
fi

# Check SSL
echo -e "\n5. SSL Configuration:"
if [[ -f config/ssl/cert.pem ]]; then
    openssl x509 -in config/ssl/cert.pem -noout -dates
else
    echo "✗ SSL not configured"
fi

# Check logs for suspicious activity
echo -e "\n6. Recent Security Events:"
docker compose logs nginx | grep -E "403|401" | tail -10 || echo "No security events found"
```

## Dependencies
- All services running
- Network configuration complete
- Admin access for firewall changes

## Success Criteria
- API requires authentication
- SSL/TLS enabled for all services
- Network access restricted to local network
- Security monitoring alerts configured
- All security audits pass

## Testing
```bash
# Test unauthorized access
curl -v http://mac-studio.local/api/version  # Should fail

# Test with authentication
API_KEY=$(cat config/.api-key)
curl -v -u "ollama-user:$API_KEY" https://mac-studio.local/api/version

# Run security audit
./scripts/security/security-audit.sh
```

## Notes
- Use proper certificate for production (not self-signed)
- Regularly rotate API keys
- Monitor security alerts in Grafana
- Consider VPN for remote access