use axum::{
    http::{header, Method},
    routing::{get, post},
    Router,
};
use std::{net::SocketAddr, sync::Arc};
use tower_http::{cors::CorsLayer, trace::TraceLayer};
use tracing::info;

mod config;
mod converters;
mod error;
mod handlers;
mod metrics;
mod models;

use config::Config;
use handlers::chat::{handle_chat, handle_generate, AppState};
use handlers::models::handle_list_models;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .init();

    let config = Config::from_env();

    info!("Starting Mistral-Ollama API proxy");
    info!("Mistral backend: {}", config.mistral_url);
    info!("Listening on: {}", config.bind_address);

    let client = reqwest::Client::builder()
        .timeout(config.request_timeout())
        .build()
        .expect("Failed to build HTTP client");

    let state = Arc::new(AppState {
        client,
        mistral_url: config.mistral_url.clone(),
        channel_buffer_size: config.channel_buffer_size,
        max_line_length: config.max_line_length,
    });

    let mut cors = CorsLayer::new()
        .allow_methods([Method::GET, Method::POST, Method::OPTIONS])
        .allow_headers([header::CONTENT_TYPE, header::AUTHORIZATION]);

    // Configure allowed origins
    for origin in &config.cors_allowed_origins {
        cors = cors.allow_origin(
            origin
                .parse::<axum::http::HeaderValue>()
                .unwrap_or_else(|_| panic!("Invalid CORS origin: {origin}")),
        );
    }

    let app = Router::new()
        .route("/api/generate", post(handle_generate))
        .route("/api/chat", post(handle_chat))
        .route("/api/tags", get(handle_list_models))
        .route("/api/models", get(handle_list_models))
        .route("/api/version", get(handle_version))
        .route("/api/metrics", get(handle_metrics))
        .route("/metrics", get(handle_metrics))
        .route("/", get(handle_health))
        .layer(cors)
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    let addr: SocketAddr = config.bind_address.parse().expect("Invalid bind address");

    info!("Server starting on {}", addr);

    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("Failed to bind to address");

    axum::serve(listener, app)
        .await
        .expect("Server failed to start");
}

async fn handle_health() -> &'static str {
    "Ollama is running"
}

async fn handle_version() -> axum::Json<serde_json::Value> {
    axum::Json(serde_json::json!({
        "version": "0.1.0-mistral-proxy"
    }))
}

async fn handle_metrics() -> impl axum::response::IntoResponse {
    use axum::http::StatusCode;

    let metrics = metrics::export_metrics();
    (
        StatusCode::OK,
        [(header::CONTENT_TYPE, "text/plain")],
        metrics,
    )
}
