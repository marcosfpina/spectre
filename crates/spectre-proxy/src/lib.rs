//! SPECTRE Proxy - API Gateway
//! 
//! Handles HTTP ingress, authentication, rate limiting, and routing to NATS.

pub mod gateway;
pub mod routes;
pub mod tls;
pub mod error;
pub mod auth;
pub mod circuit;

pub use gateway::start_server;
