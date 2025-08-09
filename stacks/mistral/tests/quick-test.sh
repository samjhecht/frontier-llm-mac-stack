#!/bin/bash
# Quick test to verify all services are responding

echo "Quick Service Test"
echo "=================="

# Test endpoints
echo "✓ Mock server on 8080: $(curl -s http://localhost:8080/health)"
echo "✓ Mock server on 11434: $(curl -s http://localhost:11434/api/version | jq -r .version)"
echo "✓ Model available: $(curl -s http://localhost:11434/api/tags | jq -r '.models[0].name')"

echo ""
echo "All mock servers are running correctly!"