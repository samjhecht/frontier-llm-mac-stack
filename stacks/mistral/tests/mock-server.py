#!/usr/bin/env python3
"""
Mock Mistral server for testing integration tests
"""
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import sys
import logging
import time

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Maximum request size (10MB)
MAX_REQUEST_SIZE = 10 * 1024 * 1024

class MockMistralHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'OK')
        elif self.path == '/v1/models':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                "models": [
                    {
                        "id": "qwen2.5-coder:32b",
                        "object": "model",
                        "created": 1700000000,
                        "owned_by": "mistral"
                    }
                ]
            }
            self.wfile.write(json.dumps(response).encode())
        elif self.path == '/api/tags':
            # Ollama API endpoint for listing models
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                "models": [
                    {
                        "name": "qwen2.5-coder:32b",
                        "modified_at": "2024-01-01T00:00:00Z",
                        "size": 19000000000,
                        "digest": "sha256:abcdef123456",
                        "details": {
                            "format": "gguf",
                            "family": "qwen",
                            "parameter_size": "32B",
                            "quantization_level": "Q4_0"
                        }
                    }
                ]
            }
            self.wfile.write(json.dumps(response).encode())
        elif self.path == '/api/version':
            # Ollama version endpoint
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {"version": "0.1.0"}
            self.wfile.write(json.dumps(response).encode())
        else:
            self.send_response(404)
            self.end_headers()
            
    def do_POST(self):
        # Check request size
        content_length = int(self.headers.get('Content-Length', 0))
        if content_length > MAX_REQUEST_SIZE:
            self.send_response(413)  # Payload Too Large
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            error = {"error": f"Request too large. Maximum size is {MAX_REQUEST_SIZE} bytes"}
            self.wfile.write(json.dumps(error).encode())
            logger.warning(f"Request rejected: size {content_length} exceeds limit")
            return
            
        post_data = self.rfile.read(content_length)
        logger.info(f"Received {self.command} request to {self.path} ({content_length} bytes)")
        
        if self.path == '/v1/chat/completions':
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            
            response = {
                "id": "chatcmpl-123",
                "object": "chat.completion",
                "created": 1700000000,
                "model": "qwen2.5-coder:32b",
                "choices": [{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "Hello! This is a mock response."
                    },
                    "finish_reason": "stop"
                }],
                "usage": {
                    "prompt_tokens": 10,
                    "completion_tokens": 20,
                    "total_tokens": 30
                }
            }
            self.wfile.write(json.dumps(response).encode())
        elif self.path == '/api/generate':
            # Ollama generate endpoint
            try:
                request = json.loads(post_data)
                stream = request.get('stream', False)
                
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                
                if stream:
                    # Send streaming response
                    for i in range(3):
                        chunk = {
                            "model": request.get('model', 'qwen2.5-coder:32b'),
                            "created_at": time.strftime('%Y-%m-%dT%H:%M:%S.%fZ'),
                            "response": f"Chunk {i+1} ",
                            "done": i == 2
                        }
                        self.wfile.write((json.dumps(chunk) + "\n").encode())
                        self.wfile.flush()
                else:
                    # Send complete response
                    response = {
                        "model": request.get('model', 'qwen2.5-coder:32b'),
                        "created_at": time.strftime('%Y-%m-%dT%H:%M:%S.%fZ'),
                        "response": "This is a mock Ollama response.",
                        "done": True,
                        "context": [1, 2, 3],
                        "total_duration": 1000000000,
                        "load_duration": 50000000,
                        "prompt_eval_count": 10,
                        "prompt_eval_duration": 100000000,
                        "eval_count": 20,
                        "eval_duration": 850000000
                    }
                    self.wfile.write(json.dumps(response).encode())
            except json.JSONDecodeError:
                self.send_response(400)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                error = {"error": "Invalid JSON in request body"}
                self.wfile.write(json.dumps(error).encode())
        elif self.path == '/api/pull':
            # Ollama pull endpoint (mock)
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                "status": "success",
                "digest": "sha256:abcdef123456",
                "total": 1000000,
                "completed": 1000000
            }
            self.wfile.write(json.dumps(response).encode())
        elif self.path == '/api/embeddings':
            # Ollama embeddings endpoint
            try:
                request = json.loads(post_data)
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                response = {
                    "embedding": [0.1] * 768  # Mock 768-dimensional embedding
                }
                self.wfile.write(json.dumps(response).encode())
            except json.JSONDecodeError:
                self.send_response(400)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                error = {"error": "Invalid JSON in request body"}
                self.wfile.write(json.dumps(error).encode())
        else:
            self.send_response(404)
            self.end_headers()
            
    def log_message(self, format, *args):
        # Use custom logger instead of default
        logger.debug(format % args)

if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    server = HTTPServer(('0.0.0.0', port), MockMistralHandler)
    print(f"Mock Mistral server running on port {port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down mock server")
        server.shutdown()