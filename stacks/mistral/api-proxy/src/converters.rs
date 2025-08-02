use chrono::Utc;
use serde_json::json;

use crate::models::mistral::MistralChatResponse;
use crate::models::ollama::{OllamaChatResponse, OllamaGenerateResponse, OllamaMessage};

pub fn convert_mistral_to_ollama_chat(
    mistral_response: MistralChatResponse,
    model_name: String,
) -> OllamaChatResponse {
    let message = mistral_response
        .choices
        .first()
        .and_then(|c| c.message.as_ref())
        .map(|m| OllamaMessage {
            role: m.role.clone(),
            content: m.content.clone(),
        })
        .unwrap_or_else(|| OllamaMessage {
            role: "assistant".to_string(),
            content: String::new(),
        });

    OllamaChatResponse {
        model: model_name,
        created_at: Utc::now().to_rfc3339(),
        message,
        done: true,
        total_duration: None,
        load_duration: None,
        prompt_eval_count: mistral_response.usage.as_ref().map(|u| u.prompt_tokens),
        prompt_eval_duration: None,
        eval_count: mistral_response.usage.as_ref().map(|u| u.completion_tokens),
        eval_duration: None,
    }
}

pub fn convert_mistral_to_ollama_generate(
    mistral_response: MistralChatResponse,
    model_name: String,
) -> OllamaGenerateResponse {
    let content = mistral_response
        .choices
        .first()
        .and_then(|c| c.message.as_ref())
        .map(|m| m.content.clone())
        .unwrap_or_default();

    OllamaGenerateResponse {
        model: model_name,
        created_at: Utc::now().to_rfc3339(),
        response: content,
        done: true,
        context: None,
        total_duration: None,
        load_duration: None,
        prompt_eval_count: mistral_response.usage.as_ref().map(|u| u.prompt_tokens),
        prompt_eval_duration: None,
        eval_count: mistral_response.usage.as_ref().map(|u| u.completion_tokens),
        eval_duration: None,
    }
}

pub fn create_streaming_chunk(
    model_name: &str,
    content: &str,
    role: &str,
    is_chat: bool,
) -> serde_json::Value {
    if is_chat {
        json!({
            "model": model_name,
            "created_at": Utc::now().to_rfc3339(),
            "message": {
                "role": role,
                "content": content
            },
            "done": false
        })
    } else {
        json!({
            "model": model_name,
            "created_at": Utc::now().to_rfc3339(),
            "response": content,
            "done": false
        })
    }
}

pub fn create_done_chunk(model_name: &str) -> serde_json::Value {
    json!({
        "done": true,
        "model": model_name,
        "created_at": Utc::now().to_rfc3339(),
    })
}

#[cfg(test)]
#[allow(clippy::bool_assert_comparison)]
mod tests {
    use super::*;
    use crate::models::mistral::{MistralChoice, MistralMessage, MistralUsage};

    #[test]
    fn test_convert_mistral_to_ollama_chat() {
        let mistral_response = MistralChatResponse {
            id: "test-id".to_string(),
            object: "chat.completion".to_string(),
            created: 1234567890,
            model: "mistral-7b".to_string(),
            choices: vec![MistralChoice {
                index: 0,
                message: Some(MistralMessage {
                    role: "assistant".to_string(),
                    content: "Hello!".to_string(),
                }),
                delta: None,
                finish_reason: Some("stop".to_string()),
            }],
            usage: Some(MistralUsage {
                prompt_tokens: 10,
                completion_tokens: 5,
                total_tokens: 15,
            }),
        };

        let ollama_response =
            convert_mistral_to_ollama_chat(mistral_response, "mistral:latest".to_string());

        assert_eq!(ollama_response.model, "mistral:latest");
        assert_eq!(ollama_response.message.role, "assistant");
        assert_eq!(ollama_response.message.content, "Hello!");
        assert!(ollama_response.done);
        assert_eq!(ollama_response.prompt_eval_count, Some(10));
        assert_eq!(ollama_response.eval_count, Some(5));
    }

    #[test]
    fn test_convert_mistral_to_ollama_generate() {
        let mistral_response = MistralChatResponse {
            id: "test-id".to_string(),
            object: "chat.completion".to_string(),
            created: 1234567890,
            model: "mistral-7b".to_string(),
            choices: vec![MistralChoice {
                index: 0,
                message: Some(MistralMessage {
                    role: "assistant".to_string(),
                    content: "Generated text".to_string(),
                }),
                delta: None,
                finish_reason: Some("stop".to_string()),
            }],
            usage: Some(MistralUsage {
                prompt_tokens: 20,
                completion_tokens: 15,
                total_tokens: 35,
            }),
        };

        let ollama_response =
            convert_mistral_to_ollama_generate(mistral_response, "mistral:latest".to_string());

        assert_eq!(ollama_response.model, "mistral:latest");
        assert_eq!(ollama_response.response, "Generated text");
        assert!(ollama_response.done);
        assert_eq!(ollama_response.prompt_eval_count, Some(20));
        assert_eq!(ollama_response.eval_count, Some(15));
    }

    #[test]
    fn test_create_streaming_chunk_chat() {
        let chunk = create_streaming_chunk("mistral:latest", "Hello", "assistant", true);

        assert_eq!(chunk["model"], "mistral:latest");
        assert_eq!(chunk["message"]["role"], "assistant");
        assert_eq!(chunk["message"]["content"], "Hello");
        assert_eq!(chunk["done"], false);
    }

    #[test]
    fn test_create_streaming_chunk_generate() {
        let chunk = create_streaming_chunk("mistral:latest", "Generated", "assistant", false);

        assert_eq!(chunk["model"], "mistral:latest");
        assert_eq!(chunk["response"], "Generated");
        assert_eq!(chunk["done"], false);
    }

    #[test]
    fn test_create_done_chunk() {
        let chunk = create_done_chunk("mistral:latest");

        assert_eq!(chunk["model"], "mistral:latest");
        assert_eq!(chunk["done"], true);
        assert!(chunk["created_at"].is_string());
    }
}
