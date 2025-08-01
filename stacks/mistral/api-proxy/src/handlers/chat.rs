use axum::{
    body::Body,
    extract::State,
    http::{header, HeaderMap, HeaderValue},
    response::{IntoResponse, Response},
    Json,
};
use futures::StreamExt;
use reqwest::Client;
use serde_json::json;
use std::sync::Arc;
use tokio_stream::wrappers::ReceiverStream;
use tracing::{error, info};

use crate::error::{AppError, Result};
use crate::models::mistral::{MistralChatRequest, MistralChatResponse, MistralMessage, MistralStreamChunk};
use crate::models::ollama::{OllamaChatRequest, OllamaChatResponse, OllamaGenerateRequest, OllamaGenerateResponse, OllamaMessage};

#[derive(Clone)]
pub struct AppState {
    pub client: Client,
    pub mistral_url: String,
}

impl From<OllamaMessage> for MistralMessage {
    fn from(msg: OllamaMessage) -> Self {
        MistralMessage {
            role: msg.role,
            content: msg.content,
        }
    }
}

pub async fn handle_generate(
    State(state): State<Arc<AppState>>,
    Json(req): Json<OllamaGenerateRequest>,
) -> Result<Response> {
    info!("Handling generate request for model: {}", req.model);
    
    let mistral_req = MistralChatRequest {
        model: translate_model_name(&req.model),
        messages: vec![MistralMessage {
            role: "user".to_string(),
            content: req.prompt.clone(),
        }],
        stream: req.stream,
        temperature: None,
        top_p: None,
        max_tokens: None,
        random_seed: None,
    };

    if req.stream.unwrap_or(false) {
        handle_streaming_request(state, mistral_req, false).await
    } else {
        handle_sync_request(state, mistral_req, false).await
    }
}

pub async fn handle_chat(
    State(state): State<Arc<AppState>>,
    Json(req): Json<OllamaChatRequest>,
) -> Result<Response> {
    info!("Handling chat request for model: {}", req.model);
    
    let mistral_req = MistralChatRequest {
        model: translate_model_name(&req.model),
        messages: req.messages.into_iter().map(|m| m.into()).collect(),
        stream: req.stream,
        temperature: None,
        top_p: None,
        max_tokens: None,
        random_seed: None,
    };

    if req.stream.unwrap_or(false) {
        handle_streaming_request(state, mistral_req, true).await
    } else {
        handle_sync_request(state, mistral_req, true).await
    }
}

async fn handle_sync_request(
    state: Arc<AppState>,
    req: MistralChatRequest,
    is_chat: bool,
) -> Result<Response> {
    let url = format!("{}/v1/chat/completions", state.mistral_url);
    
    let response = state.client
        .post(&url)
        .json(&req)
        .send()
        .await?;

    if !response.status().is_success() {
        let error_text = response.text().await.unwrap_or_else(|_| "Unknown error".to_string());
        error!("Mistral API error: {}", error_text);
        return Err(AppError::InternalError);
    }

    let mistral_response: MistralChatResponse = response.json().await?;
    
    let ollama_response = if is_chat {
        let message = mistral_response.choices.first()
            .and_then(|c| c.message.as_ref())
            .map(|m| OllamaMessage {
                role: m.role.clone(),
                content: m.content.clone(),
            })
            .unwrap_or_else(|| OllamaMessage {
                role: "assistant".to_string(),
                content: String::new(),
            });

        serde_json::to_value(OllamaChatResponse {
            model: req.model,
            created_at: chrono::Utc::now().to_rfc3339(),
            message,
            done: true,
            total_duration: None,
            load_duration: None,
            prompt_eval_count: mistral_response.usage.as_ref().map(|u| u.prompt_tokens),
            prompt_eval_duration: None,
            eval_count: mistral_response.usage.as_ref().map(|u| u.completion_tokens),
            eval_duration: None,
        })?
    } else {
        let content = mistral_response.choices.first()
            .and_then(|c| c.message.as_ref())
            .map(|m| m.content.clone())
            .unwrap_or_default();

        serde_json::to_value(OllamaGenerateResponse {
            model: req.model,
            created_at: chrono::Utc::now().to_rfc3339(),
            response: content,
            done: true,
            context: None,
            total_duration: None,
            load_duration: None,
            prompt_eval_count: mistral_response.usage.as_ref().map(|u| u.prompt_tokens),
            prompt_eval_duration: None,
            eval_count: mistral_response.usage.as_ref().map(|u| u.completion_tokens),
            eval_duration: None,
        })?
    };

    Ok(Json(ollama_response).into_response())
}

async fn handle_streaming_request(
    state: Arc<AppState>,
    req: MistralChatRequest,
    is_chat: bool,
) -> Result<Response> {
    let url = format!("{}/v1/chat/completions", state.mistral_url);
    let model_name = req.model.clone();
    
    let response = state.client
        .post(&url)
        .json(&req)
        .send()
        .await?;

    if !response.status().is_success() {
        let error_text = response.text().await.unwrap_or_else(|_| "Unknown error".to_string());
        error!("Mistral API error: {}", error_text);
        return Err(AppError::StreamingError(error_text));
    }

    let mut headers = HeaderMap::new();
    headers.insert(header::CONTENT_TYPE, HeaderValue::from_static("text/event-stream"));
    headers.insert(header::CACHE_CONTROL, HeaderValue::from_static("no-cache"));
    headers.insert(header::CONNECTION, HeaderValue::from_static("keep-alive"));

    let stream = response.bytes_stream();
    let (tx, rx) = tokio::sync::mpsc::channel(100);

    tokio::spawn(async move {
        let mut buffer = String::new();
        let mut stream = Box::pin(stream);
        
        while let Some(chunk_result) = stream.next().await {
            match chunk_result {
                Ok(chunk) => {
                    let chunk_str = String::from_utf8_lossy(&chunk);
                    buffer.push_str(&chunk_str);
                    
                    while let Some(line_end) = buffer.find('\n') {
                        let line = buffer.drain(..=line_end).collect::<String>();
                        let line = line.trim();
                        
                        if line.starts_with("data: ") {
                            let json_str = &line[6..];
                            if json_str == "[DONE]" {
                                let _ = tx.send(Ok(json!({
                                    "done": true,
                                    "model": model_name.clone(),
                                    "created_at": chrono::Utc::now().to_rfc3339(),
                                }).to_string())).await;
                                break;
                            }
                            
                            if let Ok(chunk) = serde_json::from_str::<MistralStreamChunk>(json_str) {
                                if let Some(choice) = chunk.choices.first() {
                                    if let Some(delta) = &choice.delta {
                                        let ollama_chunk = if is_chat {
                                            json!({
                                                "model": model_name.clone(),
                                                "created_at": chrono::Utc::now().to_rfc3339(),
                                                "message": {
                                                    "role": delta.role.clone(),
                                                    "content": delta.content.clone()
                                                },
                                                "done": false
                                            })
                                        } else {
                                            json!({
                                                "model": model_name.clone(),
                                                "created_at": chrono::Utc::now().to_rfc3339(),
                                                "response": delta.content.clone(),
                                                "done": false
                                            })
                                        };
                                        
                                        let _ = tx.send(Ok(ollama_chunk.to_string())).await;
                                    }
                                }
                            }
                        }
                    }
                }
                Err(e) => {
                    error!("Stream error: {}", e);
                    let _ = tx.send(Err(e.to_string())).await;
                    break;
                }
            }
        }
    });

    let stream = ReceiverStream::new(rx);
    let body = Body::from_stream(stream.map(|result| {
        result.map(|data| format!("data: {}\n\n", data))
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e))
    }));

    Ok((headers, body).into_response())
}

fn translate_model_name(ollama_name: &str) -> String {
    match ollama_name {
        "mistral:latest" => "mistral-7b".to_string(),
        "mistral:7b" => "mistral-7b".to_string(),
        "mixtral:latest" => "mixtral-8x7b".to_string(),
        "mixtral:8x7b" => "mixtral-8x7b".to_string(),
        name => name.to_string(),
    }
}