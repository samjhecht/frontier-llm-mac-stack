use axum::http::StatusCode;
use axum_test::TestServer;
use mistral_ollama_proxy::metrics;

#[tokio::test]
async fn test_metrics_endpoint() {
    // Create test server with minimal configuration
    let app = create_test_app().await;
    let server = TestServer::new(app).unwrap();

    // Test /metrics endpoint
    let response = server.get("/metrics").await;
    assert_eq!(response.status_code(), StatusCode::OK);

    let content_type = response.headers().get("content-type").unwrap();
    assert_eq!(content_type, "text/plain");

    let body = response.text();
    assert!(body.contains("# HELP"));
    assert!(body.contains("# TYPE"));
}

#[tokio::test]
async fn test_api_metrics_endpoint() {
    let app = create_test_app().await;
    let server = TestServer::new(app).unwrap();

    // Test /api/metrics endpoint
    let response = server.get("/api/metrics").await;
    assert_eq!(response.status_code(), StatusCode::OK);

    let body = response.text();
    assert!(body.contains("# HELP"));
    assert!(body.contains("# TYPE"));
}

#[tokio::test]
async fn test_metrics_recording() {
    let app = create_test_app().await;
    let server = TestServer::new(app).unwrap();

    // Make a request to generate endpoint
    let response = server
        .post("/api/generate")
        .json(&serde_json::json!({
            "model": "test-model",
            "prompt": "Hello",
            "stream": false
        }))
        .await;

    // Even if the request fails (no backend), metrics should be recorded
    assert!(
        response.status_code() == StatusCode::INTERNAL_SERVER_ERROR
            || response.status_code() == StatusCode::BAD_GATEWAY
    );

    // Check metrics were recorded
    let metrics_response = server.get("/metrics").await;
    let metrics_body = metrics_response.text();

    assert!(metrics_body.contains("mistral_http_requests_total"));
    assert!(metrics_body.contains("mistral_active_requests"));
    assert!(metrics_body.contains("generate"));
}

#[tokio::test]
async fn test_metrics_after_chat_request() {
    let app = create_test_app().await;
    let server = TestServer::new(app).unwrap();

    // Make a request to chat endpoint
    let _response = server
        .post("/api/chat")
        .json(&serde_json::json!({
            "model": "test-model",
            "messages": [{"role": "user", "content": "Hello"}],
            "stream": false
        }))
        .await;

    // Check metrics were recorded
    let metrics_response = server.get("/metrics").await;
    let metrics_body = metrics_response.text();

    assert!(metrics_body.contains("mistral_http_requests_total"));
    assert!(metrics_body.contains("chat"));
}

// Helper function to create test app
async fn create_test_app() -> axum::Router {
    use axum::{
        routing::{get, post},
        Router,
    };
    use std::sync::Arc;
    use tower_http::cors::CorsLayer;

    // Import necessary modules from the main crate
    use mistral_ollama_proxy::{
        handlers::{
            chat::{handle_chat, handle_generate, AppState},
            models::handle_list_models,
        },
    };

    // Initialize metrics
    lazy_static::initialize(&metrics::HTTP_REQUESTS_TOTAL);
    lazy_static::initialize(&metrics::ACTIVE_REQUESTS);

    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(5))
        .build()
        .unwrap();

    let state = Arc::new(AppState {
        client,
        mistral_url: "http://localhost:0".to_string(), // Non-existent backend
        channel_buffer_size: 100,
        max_line_length: 1_000_000,
    });

    Router::new()
        .route("/api/generate", post(handle_generate))
        .route("/api/chat", post(handle_chat))
        .route("/api/tags", get(handle_list_models))
        .route("/api/models", get(handle_list_models))
        .route("/api/version", get(handle_version))
        .route("/api/metrics", get(handle_metrics))
        .route("/metrics", get(handle_metrics))
        .route("/", get(handle_health))
        .layer(CorsLayer::permissive())
        .with_state(state)
}

async fn handle_health() -> &'static str {
    "Ollama is running"
}

async fn handle_version() -> axum::Json<serde_json::Value> {
    axum::Json(serde_json::json!({
        "version": "0.1.0-test"
    }))
}

async fn handle_metrics() -> impl axum::response::IntoResponse {
    use axum::http::{header, StatusCode};

    let metrics = metrics::export_metrics();
    (
        StatusCode::OK,
        [(header::CONTENT_TYPE, "text/plain")],
        metrics,
    )
}
