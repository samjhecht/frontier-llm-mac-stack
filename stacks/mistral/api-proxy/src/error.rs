use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use thiserror::Error;

#[derive(Error, Debug)]
#[allow(clippy::enum_variant_names)]
pub enum AppError {
    #[error("Request to backend failed: {message} (URL: {url})")]
    RequestError {
        message: String,
        url: String,
        #[source]
        source: reqwest::Error,
    },

    #[error("Failed to parse JSON: {context}")]
    JsonError {
        context: String,
        #[source]
        source: serde_json::Error,
    },

    #[error("Streaming error: {message} (endpoint: {endpoint})")]
    StreamingError { message: String, endpoint: String },

    #[error("Internal server error: {context}")]
    InternalError { context: String },
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, error_message) = match self {
            AppError::RequestError { message, url, .. } => (
                StatusCode::BAD_GATEWAY,
                format!("Backend request failed: {message} (URL: {url})"),
            ),
            AppError::JsonError { context, .. } => (
                StatusCode::BAD_REQUEST,
                format!("JSON parsing error: {context}"),
            ),
            AppError::StreamingError { message, endpoint } => (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("Streaming error: {message} (endpoint: {endpoint})"),
            ),
            AppError::InternalError { context } => (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("Internal server error: {context}"),
            ),
        };

        let body = Json(json!({
            "error": error_message,
        }));

        (status, body).into_response()
    }
}

impl AppError {
    pub fn request_error(url: String, source: reqwest::Error) -> Self {
        AppError::RequestError {
            message: source.to_string(),
            url,
            source,
        }
    }

    pub fn json_error(context: &str, source: serde_json::Error) -> Self {
        AppError::JsonError {
            context: context.to_string(),
            source,
        }
    }

    pub fn streaming_error(message: String, endpoint: &str) -> Self {
        AppError::StreamingError {
            message,
            endpoint: endpoint.to_string(),
        }
    }

    pub fn internal_error(context: &str) -> Self {
        AppError::InternalError {
            context: context.to_string(),
        }
    }
}

impl From<reqwest::Error> for AppError {
    fn from(err: reqwest::Error) -> Self {
        AppError::request_error("Unknown URL".to_string(), err)
    }
}

impl From<serde_json::Error> for AppError {
    fn from(err: serde_json::Error) -> Self {
        AppError::json_error("Unknown context", err)
    }
}

pub type Result<T> = std::result::Result<T, AppError>;
