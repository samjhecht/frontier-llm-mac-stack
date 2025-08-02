use axum::{extract::State, response::IntoResponse, Json};
use std::sync::Arc;
use tracing::info;

use crate::error::{AppError, Result};
use crate::handlers::chat::AppState;
use crate::models::mistral::MistralModelsResponse;
use crate::models::ollama::{OllamaListResponse, OllamaModel};

pub async fn handle_list_models(State(state): State<Arc<AppState>>) -> Result<impl IntoResponse> {
    info!("Listing available models");

    let url = format!("{}/v1/models", state.mistral_url);

    let response = state
        .client
        .get(&url)
        .send()
        .await
        .map_err(|e| AppError::request_error(url.clone(), e))?;

    if !response.status().is_success() {
        let default_models = vec![
            OllamaModel {
                name: "mistral:latest".to_string(),
                modified_at: chrono::Utc::now().to_rfc3339(),
                size: crate::config::model_sizes::MODEL_7B_SIZE,
                digest: "default".to_string(),
            },
            OllamaModel {
                name: "mistral:7b".to_string(),
                modified_at: chrono::Utc::now().to_rfc3339(),
                size: crate::config::model_sizes::MODEL_7B_SIZE,
                digest: "default".to_string(),
            },
        ];

        return Ok(Json(OllamaListResponse {
            models: default_models,
        }));
    }

    let mistral_models: MistralModelsResponse = response
        .json()
        .await
        .map_err(|e| AppError::request_error(url.clone(), e))?;

    let ollama_models = mistral_models
        .data
        .into_iter()
        .map(|m| {
            let name = match m.id.as_str() {
                "mistral-7b" => "mistral:latest".to_string(),
                "mixtral-8x7b" => "mixtral:latest".to_string(),
                id => format!("{id}:latest"),
            };

            OllamaModel {
                name,
                modified_at: chrono::Utc::now().to_rfc3339(),
                size: estimate_model_size(&m.id),
                digest: format!("sha256:{}", &m.id),
            }
        })
        .collect();

    Ok(Json(OllamaListResponse {
        models: ollama_models,
    }))
}

fn estimate_model_size(model_id: &str) -> i64 {
    use crate::config::model_sizes::*;

    match model_id {
        id if id.contains("7b") => MODEL_7B_SIZE,
        id if id.contains("8x7b") => MODEL_8X7B_SIZE,
        id if id.contains("70b") => MODEL_70B_SIZE,
        _ => DEFAULT_MODEL_SIZE,
    }
}
