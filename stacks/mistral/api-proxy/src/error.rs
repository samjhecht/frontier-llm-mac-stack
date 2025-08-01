use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum AppError {
    #[error("Request error: {0}")]
    RequestError(#[from] reqwest::Error),
    
    #[error("JSON error: {0}")]
    JsonError(#[from] serde_json::Error),
    
    #[error("Model not found: {0}")]
    ModelNotFound(String),
    
    #[error("Invalid request format")]
    InvalidRequest,
    
    #[error("Streaming error: {0}")]
    StreamingError(String),
    
    #[error("Internal server error")]
    InternalError,
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, error_message) = match self {
            AppError::ModelNotFound(ref model) => (
                StatusCode::NOT_FOUND,
                format!("Model '{}' not found", model),
            ),
            AppError::InvalidRequest => (
                StatusCode::BAD_REQUEST,
                "Invalid request format".to_string(),
            ),
            AppError::RequestError(ref e) => (
                StatusCode::BAD_GATEWAY,
                format!("Backend request failed: {}", e),
            ),
            AppError::JsonError(ref e) => (
                StatusCode::BAD_REQUEST,
                format!("JSON parsing error: {}", e),
            ),
            AppError::StreamingError(ref e) => (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("Streaming error: {}", e),
            ),
            AppError::InternalError => (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Internal server error".to_string(),
            ),
        };

        let body = Json(json!({
            "error": error_message,
        }));

        (status, body).into_response()
    }
}

pub type Result<T> = std::result::Result<T, AppError>;