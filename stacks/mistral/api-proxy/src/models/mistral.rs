use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize, Serialize)]
pub struct MistralChatRequest {
    pub model: String,
    pub messages: Vec<MistralMessage>,
    pub stream: Option<bool>,
    pub temperature: Option<f32>,
    pub top_p: Option<f32>,
    pub max_tokens: Option<i32>,
    pub random_seed: Option<i32>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct MistralMessage {
    pub role: String,
    pub content: String,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct MistralChatResponse {
    pub id: String,
    pub object: String,
    pub created: i64,
    pub model: String,
    pub choices: Vec<MistralChoice>,
    pub usage: Option<MistralUsage>,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct MistralChoice {
    pub index: i32,
    pub message: Option<MistralMessage>,
    pub delta: Option<MistralMessage>,
    pub finish_reason: Option<String>,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct MistralUsage {
    pub prompt_tokens: i32,
    pub completion_tokens: i32,
    pub total_tokens: i32,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct MistralStreamChunk {
    pub id: String,
    pub object: String,
    pub created: i64,
    pub model: String,
    pub choices: Vec<MistralChoice>,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct MistralModelsResponse {
    pub object: String,
    pub data: Vec<MistralModel>,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct MistralModel {
    pub id: String,
    pub object: String,
    pub created: i64,
    pub owned_by: String,
}
