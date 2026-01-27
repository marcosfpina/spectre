//! SPECTRE Proxy - API Gateway
//!
//! Handles HTTP ingress, authentication, rate limiting, and routing to NATS.

pub mod auth;
pub mod circuit;
pub mod error;
pub mod gateway;
pub mod routes;
pub mod tls;

pub use gateway::start_server;
