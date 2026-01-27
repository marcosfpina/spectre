//! SPECTRE Observability - Metrics and Tracing
//!
//! Provides centralized logging, tracing, and metrics setup for all SPECTRE services.
//! Integrates OpenTelemetry (OTLP) for distributed tracing and Prometheus for metrics.

use opentelemetry::{global, KeyValue};
use opentelemetry_otlp::WithExportConfig;
use opentelemetry_sdk::{
    propagation::TraceContextPropagator, resource::Resource, trace as sdktrace,
};
use opentelemetry_semantic_conventions::resource;
use prometheus::{Encoder, TextEncoder};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter, Registry};

/// Initialize observability (Tracing + Logging + Metrics)
///
/// # Arguments
/// * `service_name` - The name of the service (e.g., "spectre-proxy")
pub fn init(service_name: &str) {
    // 1. Set global propagator
    global::set_text_map_propagator(TraceContextPropagator::new());

    // 2. Configure Logging Layer
    let log_level = std::env::var("RUST_LOG").unwrap_or_else(|_| "info".to_string());
    let env_filter = EnvFilter::new(log_level);
    let log_format = std::env::var("SPECTRE_LOG_FORMAT").unwrap_or_else(|_| "pretty".to_string());

    // 3. Helper to create tracer
    let create_tracer = || {
        let otlp_endpoint = std::env::var("OTEL_EXPORTER_OTLP_ENDPOINT").ok()?;

        tracing::info!("Initializing OTLP tracing to {}", otlp_endpoint);

        let resource = Resource::new(vec![
            KeyValue::new(resource::SERVICE_NAME, service_name.to_string()),
            KeyValue::new(resource::SERVICE_VERSION, env!("CARGO_PKG_VERSION")),
        ]);

        Some(
            opentelemetry_otlp::new_pipeline()
                .tracing()
                .with_exporter(
                    opentelemetry_otlp::new_exporter()
                        .tonic()
                        .with_endpoint(otlp_endpoint),
                )
                .with_trace_config(
                    sdktrace::config()
                        .with_resource(resource)
                        .with_sampler(sdktrace::Sampler::AlwaysOn),
                )
                .install_batch(opentelemetry_sdk::runtime::Tokio)
                .expect("Failed to initialize OTLP tracer"),
        )
    };

    // 4. Compose Subscriber
    let registry = Registry::default().with(env_filter);

    if log_format == "json" {
        let fmt_layer = tracing_subscriber::fmt::layer()
            .json()
            .with_target(true)
            .with_level(true);

        let tracer = create_tracer();
        let otel_layer = tracer.map(|t| tracing_opentelemetry::layer().with_tracer(t));

        registry.with(fmt_layer).with(otel_layer).init();
    } else {
        let fmt_layer = tracing_subscriber::fmt::layer()
            .pretty()
            .with_target(true)
            .with_level(true);

        let tracer = create_tracer();
        let otel_layer = tracer.map(|t| tracing_opentelemetry::layer().with_tracer(t));

        registry.with(fmt_layer).with(otel_layer).init();
    }

    tracing::info!("Observability initialized for service: {}", service_name);
}

/// Shutdown observability (flush traces)
pub fn shutdown() {
    global::shutdown_tracer_provider();
}

/// Gather metrics for export (e.g. via /metrics endpoint)
pub fn gather_metrics() -> String {
    let mut buffer = Vec::new();
    let encoder = TextEncoder::new();
    let metric_families = prometheus::gather();
    encoder.encode(&metric_families, &mut buffer).unwrap();
    String::from_utf8(buffer).unwrap()
}
