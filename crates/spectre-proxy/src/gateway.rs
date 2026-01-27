use crate::routes::{create_router, ProxyState};
use anyhow::{Context, Result};
use spectre_events::{EventBus, EventBusConfig};
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::net::TcpListener;
use tracing::info;

pub async fn start_server() -> Result<()> {
    // 1. Connect to Event Bus
    let nats_url =
        std::env::var("NATS_URL").unwrap_or_else(|_| "nats://localhost:4222".to_string());
    let bus_config = EventBusConfig {
        urls: vec![nats_url],
        name: "spectre-proxy".to_string(),
        ..Default::default()
    };

    let event_bus = EventBus::connect_with_config(bus_config)
        .await
        .context("Failed to connect to Event Bus")?;

    use crate::circuit::{CircuitBreaker, CircuitConfig};

    // 2. Create Shared State
    let state = Arc::new(ProxyState {
        event_bus,
        circuit_breaker: CircuitBreaker::new(CircuitConfig::default()),
    });

    // 3. Build Router
    let app = create_router(state);

    // 4. Bind and Serve
    let addr = SocketAddr::from(([0, 0, 0, 0], 8080));
    info!("Spectre Proxy listening on {}", addr);

    let listener = TcpListener::bind(addr)
        .await
        .context("Failed to bind port 8080")?;

    axum::serve(listener, app).await.context("Server error")?;

    Ok(())
}
