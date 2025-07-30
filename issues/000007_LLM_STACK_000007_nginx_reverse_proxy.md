# Step 7: Nginx Reverse Proxy Configuration

## Overview
Configure Nginx as a reverse proxy to provide a unified access point for all services, handle SSL termination (future), and implement basic security measures.

## Tasks
1. Deploy Nginx container
2. Configure reverse proxy for Ollama API
3. Configure reverse proxy for Grafana
4. Implement basic security headers
5. Set up health check endpoint

## Implementation Details

### 1. Enhanced Nginx Configuration
Update `config/nginx/default.conf`:
```nginx
upstream ollama {
    server ollama:11434;
}

upstream grafana {
    server grafana:3000;
}

# Rate limiting
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=ui_limit:10m rate=30r/s;

server {
    listen 80;
    server_name localhost mac-studio.local;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Ollama API with rate limiting
    location /api/ {
        limit_req zone=api_limit burst=20 nodelay;
        
        proxy_pass http://ollama;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        
        # Long timeout for model operations
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        
        # WebSocket support for streaming
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # CORS headers for local network
        add_header Access-Control-Allow-Origin "http://localhost:*" always;
        add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
    }

    # Grafana UI
    location / {
        limit_req zone=ui_limit burst=50 nodelay;
        
        proxy_pass http://grafana;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
```

### 2. Network Security Configuration
Create `config/nginx/security.conf`:
```nginx
# Restrict to local network only
geo $allowed_network {
    default 0;
    192.168.0.0/16 1;
    10.0.0.0/8 1;
    172.16.0.0/12 1;
    127.0.0.1 1;
}
```

### 3. Deploy Nginx
```bash
docker compose up -d nginx
```

## Dependencies
- Step 5: Ollama service running
- Step 6: Grafana service running

## Success Criteria
- Nginx container running
- Ollama API accessible via http://localhost/api/
- Grafana accessible via http://localhost/
- Rate limiting working
- Security headers present in responses

## Testing
```bash
# Test Ollama API through Nginx
curl http://localhost/api/version

# Test Grafana through Nginx
curl -I http://localhost/

# Test rate limiting
for i in {1..15}; do curl http://localhost/api/version; done

# Check security headers
curl -I http://localhost/api/version | grep -E "X-Frame-Options|X-Content-Type"
```

## Notes
- SSL/TLS configuration deferred to security hardening step
- Rate limits may need adjustment based on usage patterns
- Consider implementing API key authentication in future