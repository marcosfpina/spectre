use anyhow::{Context, Result};
use rustls::ServerConfig;
use std::path::Path;
use std::fs::File;
use std::io::BufReader;

pub fn load_rustls_config(cert_path: impl AsRef<Path>, key_path: impl AsRef<Path>) -> Result<ServerConfig> {
    let cert_file = File::open(&cert_path)
        .with_context(|| format!("Failed to open cert file: {:?}", cert_path.as_ref()))?;
    let mut cert_reader = BufReader::new(cert_file);
    
    // Load certs
    let certs = rustls_pemfile::certs(&mut cert_reader)
        .collect::<std::result::Result<Vec<_>, _>>()
        .map_err(|_| anyhow::anyhow!("Failed to load certificates"))?;

    let key_file = File::open(&key_path)
        .with_context(|| format!("Failed to open key file: {:?}", key_path.as_ref()))?;
    let mut key_reader = BufReader::new(key_file);

    // Load private key
    let keys = rustls_pemfile::pkcs8_private_keys(&mut key_reader)
        .collect::<std::result::Result<Vec<_>, _>>()
        .map_err(|_| anyhow::anyhow!("Failed to load private key"))?;

    let key = keys.first()
        .ok_or_else(|| anyhow::anyhow!("No private keys found in file"))?
        .clone_key();

    let config = ServerConfig::builder()
        .with_no_client_auth()
        .with_single_cert(certs, key.into())
        .context("Failed to build server config")?;

    Ok(config)
}
