# MISTRAL_000005: Implement API Compatibility Layer

## Objective
Create an API compatibility layer to ensure Mistral.rs can work with existing tools expecting Ollama's API format, particularly for Aider integration.

## Context
Mistral.rs has its own API format that differs from Ollama's. To maintain compatibility with existing tools like Aider, we need a translation layer or configuration that maps between the APIs.

## Tasks

### 1. Analyze API Differences
- Document Ollama API endpoints and request/response formats
- Document Mistral.rs API endpoints and formats
- Identify mapping requirements

### 2. Create API Translation Service
- Implement lightweight proxy service (Rust preferred)
- Map Ollama-style requests to Mistral.rs format
- Translate responses back to Ollama format
- Handle streaming responses correctly

### 3. Configure Nginx Routing
- Update Nginx configuration for API routing
- Set up path-based routing to correct backend
- Ensure WebSocket support for streaming

### 4. Test with Aider
- Verify Aider can connect through compatibility layer
- Test chat completions and streaming
- Ensure model listing works correctly

## Implementation Details

```rust
// Example API translation logic
// stacks/mistral/api-proxy/src/main.rs

use axum::{Router, Json, extract::State};
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
struct OllamaRequest {
    model: String,
    prompt: String,
    stream: Option<bool>,
}

#[derive(Serialize)]
struct MistralRequest {
    model: String,
    messages: Vec<Message>,
    stream: bool,
}

async fn translate_completion(
    State(client): State<reqwest::Client>,
    Json(ollama_req): Json<OllamaRequest>,
) -> Result<Json<serde_json::Value>, AppError> {
    // Translate Ollama format to Mistral.rs format
    let mistral_req = MistralRequest {
        model: ollama_req.model,
        messages: vec![Message {
            role: "user".to_string(),
            content: ollama_req.prompt,
        }],
        stream: ollama_req.stream.unwrap_or(false),
    };
    
    // Forward to Mistral.rs
    let response = client
        .post("http://mistral:8080/v1/chat/completions")
        .json(&mistral_req)
        .send()
        .await?;
    
    // Translate response back
    // ...
}
```

## Success Criteria
- Aider successfully connects to Mistral.rs through compatibility layer
- All necessary Ollama API endpoints are mapped
- Performance overhead is minimal
- Streaming responses work correctly

## Estimated Changes
- ~300 lines of Rust proxy code
- ~50 lines of Nginx configuration updates
- API documentation

## Proposed Solution

### 1. Directory Structure
Create a new `api-proxy` directory within the mistral stack:
```
stacks/mistral/api-proxy/
├── Cargo.toml
├── src/
│   ├── main.rs
│   ├── handlers/
│   │   ├── mod.rs
│   │   ├── chat.rs
│   │   └── models.rs
│   ├── models/
│   │   ├── mod.rs
│   │   ├── ollama.rs
│   │   └── mistral.rs
│   └── error.rs
└── Dockerfile
```

### 2. API Mapping Analysis
Based on Ollama's API and Mistral.rs documentation:
- Ollama uses `/api/generate` for non-chat completions
- Ollama uses `/api/chat` for chat completions
- Mistral.rs uses OpenAI-compatible `/v1/chat/completions`
- Both support streaming via Server-Sent Events (SSE)

### 3. Implementation Steps
1. Create a Rust-based API proxy using Axum framework
2. Implement request/response translation between Ollama and Mistral.rs formats
3. Handle both synchronous and streaming responses
4. Add proper error handling and logging
5. Create Docker container for the proxy service
6. Update Nginx configuration to route Ollama API paths to the proxy
7. Update docker-compose to include the new proxy service

### 4. Key Translation Points
- Convert Ollama's `prompt` field to Mistral's `messages` array
- Map Ollama's model names to Mistral.rs model identifiers
- Transform streaming response formats between the two APIs
- Handle differences in error response structures