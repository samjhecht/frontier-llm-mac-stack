use axum::{
    routing::{get, post},
    Router,
};
use std::{env, net::SocketAddr, sync::Arc};
use tower_http::{
    cors::{Any, CorsLayer},
    trace::TraceLayer,
};
use tracing::info;

mod error;
mod handlers;
mod models;

use handlers::chat::{handle_chat, handle_generate, AppState};
use handlers::models::handle_list_models;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .init();

    let mistral_url = env::var("MISTRAL_URL").unwrap_or_else(|_| "http://mistral:8080".to_string());
    let bind_addr = env::var("BIND_ADDRESS").unwrap_or_else(|_| "0.0.0.0:11434".to_string());

    info!("Starting Mistral-Ollama API proxy");
    info!("Mistral backend: {}", mistral_url);
    info!("Listening on: {}", bind_addr);

    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(300))
        .build()
        .expect("Failed to build HTTP client");

    let state = Arc::new(AppState {
        client,
        mistral_url,
    });

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let app = Router::new()
        .route("/api/generate", post(handle_generate))
        .route("/api/chat", post(handle_chat))
        .route("/api/tags", get(handle_list_models))
        .route("/api/models", get(handle_list_models))
        .route("/api/version", get(handle_version))
        .route("/", get(handle_health))
        .layer(cors)
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    let addr: SocketAddr = bind_addr.parse().expect("Invalid bind address");
    
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