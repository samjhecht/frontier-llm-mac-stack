use lazy_static::lazy_static;
use prometheus::{
    register_counter_vec, register_gauge_vec, register_histogram_vec, register_int_gauge,
    CounterVec, GaugeVec, HistogramVec, IntGauge, TextEncoder,
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

    // Metal-specific performance metrics
    pub static ref METAL_MEMORY_USAGE_BYTES: GaugeVec = register_gauge_vec!(
        "mistral_metal_memory_usage_bytes",
        "Metal GPU memory usage in bytes",
        &["device_id", "memory_type"]
    )
    .unwrap();
    pub static ref METAL_COMPUTE_UTILIZATION: GaugeVec = register_gauge_vec!(
        "mistral_metal_compute_utilization_ratio",
        "Metal GPU compute utilization (0.0-1.0)",
        &["device_id"]
    )
    .unwrap();
    pub static ref BATCH_QUEUE_SIZE: IntGauge = register_int_gauge!(
        "mistral_batch_queue_size",
        "Number of requests waiting in batch queue"
    )
    .unwrap();
    pub static ref PREFILL_DURATION_SECONDS: HistogramVec = register_histogram_vec!(
        "mistral_prefill_duration_seconds",
        "Time spent in prefill phase",
        &["model", "batch_size"]
    )
    .unwrap();
    pub static ref DECODE_DURATION_SECONDS: HistogramVec = register_histogram_vec!(
        "mistral_decode_duration_seconds",
        "Time spent in decode phase per token",
        &["model", "batch_size"]
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
            // Return error metric in Prometheus format
            format!(
                "# HELP mistral_metrics_export_error Error exporting metrics\n\
                 # TYPE mistral_metrics_export_error counter\n\
                 mistral_metrics_export_error{{error=\"{}\"}} 1\n",
                e.to_string().replace('"', "'").replace('\n', " ")
            )
        })
}
