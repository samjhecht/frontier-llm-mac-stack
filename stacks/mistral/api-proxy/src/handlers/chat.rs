use axum::{
    body::Body,
    extract::State,
    http::{header, HeaderMap, HeaderValue},
    response::{IntoResponse, Response},
    Json,
};
use futures::StreamExt;
use reqwest::Client;
use std::sync::Arc;
use tokio_stream::wrappers::ReceiverStream;
use tracing::{error, info};

use crate::converters::{
    convert_mistral_to_ollama_chat, convert_mistral_to_ollama_generate, create_done_chunk,
    create_streaming_chunk,
};
use crate::error::{AppError, Result};
use crate::metrics::{
    ACTIVE_REQUESTS, GENERATE_DURATION_SECONDS, HTTP_REQUESTS_TOTAL, HTTP_REQUEST_DURATION_SECONDS,
    STREAMING_CHUNKS_TOTAL,
};
use crate::models::mistral::{
    MistralChatRequest, MistralChatResponse, MistralMessage, MistralStreamChunk,
};
use crate::models::ollama::{OllamaChatRequest, OllamaGenerateRequest, OllamaMessage};

#[derive(Clone)]
pub struct AppState {
    pub client: Client,
    pub mistral_url: String,
    pub channel_buffer_size: usize,
    pub max_line_length: usize,
}

impl From<OllamaMessage> for MistralMessage {
    fn from(msg: OllamaMessage) -> Self {
        MistralMessage {
            role: msg.role,
            content: msg.content,
        }
    }
}

fn extract_ollama_parameters(
    options: Option<serde_json::Value>,
) -> (Option<f32>, Option<f32>, Option<i32>, Option<i32>) {
    if let Some(opts) = options {
        let temperature = opts
            .get("temperature")
            .and_then(|v| v.as_f64())
            .map(|v| v as f32);

        let top_p = opts.get("top_p").and_then(|v| v.as_f64()).map(|v| v as f32);

        // Mistral doesn't support top_k directly, but we can use it to calculate max_tokens
        let max_tokens = opts
            .get("num_predict")
            .and_then(|v| v.as_i64())
            .map(|v| v as i32);

        // Mistral uses random_seed instead of repeat_penalty
        let seed = opts.get("seed").and_then(|v| v.as_i64()).map(|v| v as i32);

        (temperature, top_p, max_tokens, seed)
    } else {
        (None, None, None, None)
    }
}

pub async fn handle_generate(
    State(state): State<Arc<AppState>>,
    Json(req): Json<OllamaGenerateRequest>,
) -> Result<Response> {
    info!("Handling generate request for model: {}", req.model);

    ACTIVE_REQUESTS.inc();
    let _timer = HTTP_REQUEST_DURATION_SECONDS
        .with_label_values(&["generate"])
        .start_timer();
    let _generate_timer = GENERATE_DURATION_SECONDS
        .with_label_values(&[&req.model])
        .start_timer();

    let (temperature, top_p, max_tokens, random_seed) = extract_ollama_parameters(req.options);

    let mistral_req = MistralChatRequest {
        model: translate_model_name(&req.model),
        messages: vec![MistralMessage {
            role: "user".to_string(),
            content: req.prompt.clone(),
        }],
        stream: req.stream,
        temperature,
        top_p,
        max_tokens,
        random_seed,
    };

    let result = if req.stream.unwrap_or(false) {
        handle_streaming_request(state, mistral_req, false).await
    } else {
        handle_sync_request(state, mistral_req, false).await
    };

    ACTIVE_REQUESTS.dec();

    match &result {
        Ok(_) => HTTP_REQUESTS_TOTAL
            .with_label_values(&["generate", "success", "none"])
            .inc(),
        Err(e) => HTTP_REQUESTS_TOTAL
            .with_label_values(&["generate", "error", e.error_type()])
            .inc(),
    }

    result
}

pub async fn handle_chat(
    State(state): State<Arc<AppState>>,
    Json(req): Json<OllamaChatRequest>,
) -> Result<Response> {
    info!("Handling chat request for model: {}", req.model);

    ACTIVE_REQUESTS.inc();
    let _timer = HTTP_REQUEST_DURATION_SECONDS
        .with_label_values(&["chat"])
        .start_timer();
    let _generate_timer = GENERATE_DURATION_SECONDS
        .with_label_values(&[&req.model])
        .start_timer();

    let (temperature, top_p, max_tokens, random_seed) = extract_ollama_parameters(req.options);

    let mistral_req = MistralChatRequest {
        model: translate_model_name(&req.model),
        messages: req.messages.into_iter().map(|m| m.into()).collect(),
        stream: req.stream,
        temperature,
        top_p,
        max_tokens,
        random_seed,
    };

    let result = if req.stream.unwrap_or(false) {
        handle_streaming_request(state, mistral_req, true).await
    } else {
        handle_sync_request(state, mistral_req, true).await
    };

    ACTIVE_REQUESTS.dec();

    match &result {
        Ok(_) => HTTP_REQUESTS_TOTAL
            .with_label_values(&["chat", "success", "none"])
            .inc(),
        Err(e) => HTTP_REQUESTS_TOTAL
            .with_label_values(&["chat", "error", e.error_type()])
            .inc(),
    }

    result
}

async fn handle_sync_request(
    state: Arc<AppState>,
    req: MistralChatRequest,
    is_chat: bool,
) -> Result<Response> {
    let url = format!("{}/v1/chat/completions", state.mistral_url);

    let response = state
        .client
        .post(&url)
        .json(&req)
        .send()
        .await
        .map_err(|e| AppError::request_error(url.clone(), e))?;

    if !response.status().is_success() {
        let error_text = response
            .text()
            .await
            .unwrap_or_else(|_| "Unknown error".to_string());
        error!("Mistral API error: {}", error_text);
        return Err(AppError::internal_error(
            "Mistral API returned non-success status",
        ));
    }

    let mistral_response: MistralChatResponse = response
        .json()
        .await
        .map_err(|e| AppError::request_error(url.clone(), e))?;

    let ollama_response = if is_chat {
        serde_json::to_value(convert_mistral_to_ollama_chat(mistral_response, req.model))?
    } else {
        serde_json::to_value(convert_mistral_to_ollama_generate(
            mistral_response,
            req.model,
        ))?
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

    let response = state
        .client
        .post(&url)
        .json(&req)
        .send()
        .await
        .map_err(|e| AppError::request_error(url.clone(), e))?;

    if !response.status().is_success() {
        let error_text = response
            .text()
            .await
            .unwrap_or_else(|_| "Unknown error".to_string());
        error!("Mistral API error: {}", error_text);
        return Err(AppError::streaming_error(error_text, &url));
    }

    let mut headers = HeaderMap::new();
    headers.insert(
        header::CONTENT_TYPE,
        HeaderValue::from_static("text/event-stream"),
    );
    headers.insert(header::CACHE_CONTROL, HeaderValue::from_static("no-cache"));
    headers.insert(header::CONNECTION, HeaderValue::from_static("keep-alive"));

    let stream = response.bytes_stream();
    let (tx, rx) = tokio::sync::mpsc::channel(state.channel_buffer_size);
    let max_line_length = state.max_line_length;

    tokio::spawn(async move {
        let mut buffer = String::new();
        let mut stream = Box::pin(stream);

        while let Some(chunk_result) = stream.next().await {
            match chunk_result {
                Ok(chunk) => {
                    let chunk_str = String::from_utf8_lossy(&chunk);
                    buffer.push_str(&chunk_str);

                    // Check buffer size to prevent overflow
                    if buffer.len() > max_line_length {
                        error!(
                            "Stream buffer exceeded maximum line length of {} bytes",
                            max_line_length
                        );
                        let _ = tx.send(Err("Stream buffer overflow".to_string())).await;
                        break;
                    }

                    while let Some(line_end) = buffer.find('\n') {
                        let line = buffer.drain(..=line_end).collect::<String>();
                        let line = line.trim();

                        if let Some(json_str) = line.strip_prefix("data: ") {
                            if json_str == "[DONE]" {
                                let _ = tx
                                    .send(Ok(create_done_chunk(&model_name).to_string()))
                                    .await;
                                break;
                            }

                            if let Ok(chunk) = serde_json::from_str::<MistralStreamChunk>(json_str)
                            {
                                if let Some(choice) = chunk.choices.first() {
                                    if let Some(delta) = &choice.delta {
                                        let ollama_chunk = create_streaming_chunk(
                                            &model_name,
                                            &delta.content,
                                            &delta.role,
                                            is_chat,
                                        );

                                        let _ = tx.send(Ok(ollama_chunk.to_string())).await;
                                        STREAMING_CHUNKS_TOTAL
                                            .with_label_values(&[if is_chat {
                                                "chat"
                                            } else {
                                                "generate"
                                            }])
                                            .inc();
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
        result
            .map(|data| format!("data: {data}\n\n"))
            .map_err(std::io::Error::other)
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

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn test_translate_model_name() {
        assert_eq!(translate_model_name("mistral:latest"), "mistral-7b");
        assert_eq!(translate_model_name("mistral:7b"), "mistral-7b");
        assert_eq!(translate_model_name("mixtral:latest"), "mixtral-8x7b");
        assert_eq!(translate_model_name("mixtral:8x7b"), "mixtral-8x7b");
        assert_eq!(translate_model_name("custom-model"), "custom-model");
    }

    #[test]
    fn test_extract_ollama_parameters() {
        let options = Some(json!({
            "temperature": 0.7,
            "top_p": 0.9,
            "num_predict": 100,
            "seed": 42
        }));

        let (temp, top_p, max_tokens, seed) = extract_ollama_parameters(options);
        assert_eq!(temp, Some(0.7));
        assert_eq!(top_p, Some(0.9));
        assert_eq!(max_tokens, Some(100));
        assert_eq!(seed, Some(42));
    }

    #[test]
    fn test_extract_ollama_parameters_none() {
        let (temp, top_p, max_tokens, seed) = extract_ollama_parameters(None);
        assert_eq!(temp, None);
        assert_eq!(top_p, None);
        assert_eq!(max_tokens, None);
        assert_eq!(seed, None);
    }

    #[test]
    fn test_ollama_message_conversion() {
        let ollama_msg = OllamaMessage {
            role: "user".to_string(),
            content: "Hello, world!".to_string(),
        };

        let mistral_msg: MistralMessage = ollama_msg.into();
        assert_eq!(mistral_msg.role, "user");
        assert_eq!(mistral_msg.content, "Hello, world!");
    }
}
