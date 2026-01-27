use crate::auth::AuthUser;
use crate::error::AppError;
use axum::{
    error_handling::HandleErrorLayer,
    extract::{Json, State},
    http::StatusCode,
    routing::{get, post},
    BoxError, Router,
};
use serde_json::Value;
use spectre_core::ServiceId;
use spectre_events::{event::EventType, Event, EventBus};
use std::sync::Arc;

use crate::circuit::CircuitBreaker;

/// Proxy state shared handlers
pub struct ProxyState {
    pub event_bus: EventBus,
    pub circuit_breaker: CircuitBreaker,
}

use std::time::Duration;
use tower::buffer::BufferLayer;
use tower::limit::RateLimitLayer;
use tower::ServiceBuilder;

pub fn create_router(state: Arc<ProxyState>) -> Router {
    Router::new()
        .route("/health", get(health_check))
        .route("/api/v1/publish/:topic", post(publish_event))
        .layer(
            ServiceBuilder::new()
                .layer(HandleErrorLayer::new(|err: BoxError| async move {
                    (
                        StatusCode::INTERNAL_SERVER_ERROR,
                        format!("Unhandled error: {}", err),
                    )
                }))
                .layer(BufferLayer::new(1024))
                .layer(RateLimitLayer::new(1000, Duration::from_secs(1))),
        )
        .with_state(state)
}

async fn health_check() -> &'static str {
    "OK"
}

async fn publish_event(
    State(state): State<Arc<ProxyState>>,
    auth_user: AuthUser,
    axum::extract::Path(topic): axum::extract::Path<String>,
    Json(payload): Json<Value>,
) -> std::result::Result<Json<Value>, AppError> {
    // 1. Check Circuit Breaker
    if !state.circuit_breaker.allow_request() {
        return Err(AppError::from(
            spectre_core::SpectreError::ServiceUnavailable {
                service: "NATS Event Bus".to_string(),
                reason: "Circuit Open".to_string(),
            },
        ));
    }

    // Determine event type from topic (simplification)
    // In real app, we might map topic to specific event types or allow passing it in header
    let event_type = EventType::Custom(topic);

    // Create event with identity from token
    let event = Event::new(
        event_type,
        ServiceId::new(auth_user.0.sub), // Source from JWT
        payload,
    );

    // 2. Publish with CB tracking
    match state.event_bus.publish(&event).await {
        Ok(_) => {
            state.circuit_breaker.record_success();
            Ok(Json(serde_json::json!({
                "status": "published",
                "event_id": event.event_id
            })))
        }
        Err(e) => {
            state.circuit_breaker.record_failure();
            Err(AppError::from(e))
        }
    }
}
