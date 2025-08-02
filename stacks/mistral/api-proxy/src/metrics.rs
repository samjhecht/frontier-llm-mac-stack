use lazy_static::lazy_static;
use prometheus::{
    register_counter_vec, register_histogram_vec, register_int_gauge, CounterVec, HistogramVec,
    IntGauge, TextEncoder,
};

lazy_static! {
    pub static ref HTTP_REQUESTS_TOTAL: CounterVec = register_counter_vec!(
        "mistral_http_requests_total",
        "Total number of HTTP requests",
        &["endpoint", "status", "error_type"]
    )
    .unwrap();
    pub static ref HTTP_REQUEST_DURATION_SECONDS: HistogramVec = register_histogram_vec!(
        "mistral_http_request_duration_seconds",
        "HTTP request latency in seconds",
        &["endpoint"]
    )
    .unwrap();
    pub static ref GENERATE_TOKENS_TOTAL: CounterVec = register_counter_vec!(
        "mistral_generate_tokens_total",
        "Total number of tokens generated",
        &["model"]
    )
    .unwrap();
    pub static ref GENERATE_DURATION_SECONDS: HistogramVec = register_histogram_vec!(
        "mistral_generate_duration_seconds",
        "Time spent generating responses in seconds",
        &["model"]
    )
    .unwrap();
    pub static ref ACTIVE_REQUESTS: IntGauge = register_int_gauge!(
        "mistral_active_requests",
        "Number of active requests being processed"
    )
    .unwrap();
    pub static ref MODEL_LOAD_DURATION_SECONDS: HistogramVec = register_histogram_vec!(
        "mistral_model_load_duration_seconds",
        "Time taken to load models in seconds",
        &["model"]
    )
    .unwrap();
    pub static ref STREAMING_CHUNKS_TOTAL: CounterVec = register_counter_vec!(
        "mistral_streaming_chunks_total",
        "Total number of streaming chunks sent",
        &["endpoint"]
    )
    .unwrap();
}

pub fn export_metrics() -> String {
    let encoder = TextEncoder::new();
    let metric_families = prometheus::gather();
    encoder
        .encode_to_string(&metric_families)
        .unwrap_or_else(|e| {
            tracing::error!("Failed to encode metrics: {}", e);
            // Return empty metrics in Prometheus format rather than panic
            "# Failed to encode metrics\n".to_string()
        })
}
