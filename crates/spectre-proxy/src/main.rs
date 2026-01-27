use anyhow::Result;
use dotenv::dotenv;
use tracing::info;

#[tokio::main]
async fn main() -> Result<()> {
    // 1. Load environment variables
    dotenv().ok();

    // 2. Initialize Observability
    spectre_observability::init("spectre-proxy");

    if std::env::var("JWT_SECRET").is_err() {
        tracing::warn!("JWT_SECRET not set, using default 'secret'. DO NOT USE IN PRODUCTION.");
    }

    info!("Starting Spectre Proxy...");

    // 3. Start Server
    spectre_proxy::start_server().await?;

    Ok(())
}
