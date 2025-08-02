use std::env;
use std::time::Duration;

pub struct Config {
    pub mistral_url: String,
    pub bind_address: String,
    pub request_timeout_secs: u64,
    pub channel_buffer_size: usize,
    pub max_line_length: usize,
    pub cors_allowed_origins: Vec<String>,
}

impl Config {
    pub fn from_env() -> Self {
        Config {
            mistral_url: env::var("MISTRAL_URL")
                .unwrap_or_else(|_| "http://mistral:8080".to_string()),
            bind_address: env::var("BIND_ADDRESS").unwrap_or_else(|_| "0.0.0.0:11434".to_string()),
            request_timeout_secs: env::var("REQUEST_TIMEOUT_SECS")
                .ok()
                .and_then(|s| s.parse().ok())
                .unwrap_or(300),
            channel_buffer_size: env::var("CHANNEL_BUFFER_SIZE")
                .ok()
                .and_then(|s| s.parse().ok())
                .unwrap_or(100),
            max_line_length: env::var("MAX_LINE_LENGTH")
                .ok()
                .and_then(|s| s.parse().ok())
                .unwrap_or(1_000_000), // 1MB default max line length
            cors_allowed_origins: env::var("CORS_ALLOWED_ORIGINS")
                .ok()
                .map(|s| {
                    s.split(',')
                        .map(|origin| origin.trim().to_string())
                        .collect()
                })
                .unwrap_or_else(|| vec!["http://localhost:3000".to_string()]), // Default to Grafana
        }
    }

    pub fn request_timeout(&self) -> Duration {
        Duration::from_secs(self.request_timeout_secs)
    }
}

pub mod model_sizes {
    pub const MODEL_7B_SIZE: i64 = 4_100_000_000;
    pub const MODEL_8X7B_SIZE: i64 = 47_000_000_000;
    pub const MODEL_70B_SIZE: i64 = 40_000_000_000;
    pub const DEFAULT_MODEL_SIZE: i64 = MODEL_7B_SIZE;
}
