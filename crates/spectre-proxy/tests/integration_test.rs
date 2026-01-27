use jsonwebtoken::{encode, EncodingKey, Header};
use reqwest::StatusCode;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::time::Duration;
use tokio::time::sleep;

#[derive(Debug, Serialize, Deserialize)]
struct Claims {
    sub: String,
    exp: usize,
    role: String,
}

const BASE_URL: &str = "http://127.0.0.1:8080";

// Helper to generate a valid token
fn generate_token() -> String {
    let claims = Claims {
        sub: "test-user".to_string(),
        exp: 10000000000,
        role: "admin".to_string(),
    };
    encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret("secret".as_ref()),
    )
    .unwrap()
}

#[tokio::test]
async fn test_e2e_scenario() {
    // 1. Setup & Start Server
    // We run the server in a separate task.
    tokio::spawn(async {
        std::env::set_var("JWT_SECRET", "secret");
        std::env::set_var("NATS_URL", "nats://localhost:4222");
        if let Err(e) = spectre_proxy::start_server().await {
            eprintln!("Failed to start server: {}", e);
        }
    });

    // Wait for startup
    let client = reqwest::Client::new();
    let mut up = false;
    for _ in 0..20 {
        if client
            .get(format!("{}/health", BASE_URL))
            .send()
            .await
            .is_ok()
        {
            up = true;
            break;
        }
        sleep(Duration::from_millis(500)).await;
    }
    assert!(up, "Server failed to start");

    // 2. Health Check
    let resp = client
        .get(format!("{}/health", BASE_URL))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    // 3. Auth Rejection (Missing Token)
    let resp = client
        .post(format!("{}/api/v1/publish/test-topic", BASE_URL))
        .json(&json!({"data": "test"}))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);

    // 4. Auth Rejection (Invalid Token)
    let resp = client
        .post(format!("{}/api/v1/publish/test-topic", BASE_URL))
        .header("Authorization", "Bearer invalid-token")
        .json(&json!({"data": "test"}))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);

    // 5. Happy Path Publish
    let token = generate_token();
    let resp = client
        .post(format!("{}/api/v1/publish/test.integration", BASE_URL))
        .header("Authorization", format!("Bearer {}", token))
        .json(&json!({"foo": "bar"}))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);
    let body: serde_json::Value = resp.json().await.unwrap();
    assert_eq!(body["status"], "published");
}
