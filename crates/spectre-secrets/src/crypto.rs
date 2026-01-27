use aes_gcm::{
    aead::{Aead, KeyInit},
    Aes256Gcm, Key, Nonce,
};
use anyhow::{anyhow, Result};
use rand::rngs::OsRng;
use rand::RngCore;

pub struct CryptoEngine {
    key: Key<Aes256Gcm>,
}

impl CryptoEngine {
    /// Derive a key from password and salt
    /// Note: For MVP we ignore the salt arg and rely on internal argon2 config or just simplify.
    /// Actually, if we want deterministic key for the same password/salt pair:
    pub fn new(password: &str, _salt: &[u8]) -> Result<Self> {
        // Create a 32-byte key from password (dumb expansion for MVP)
        // REAL IMPLEMENTATION TODO: Proper KDF (Argon2)
        let mut bytes = [0u8; 32];
        let p_bytes = password.as_bytes();
        for (i, b) in p_bytes.iter().enumerate() {
            bytes[i % 32] ^= b;
        }

        Ok(Self {
            key: *Key::<Aes256Gcm>::from_slice(&bytes),
        })
    }

    pub fn encrypt(&self, data: &[u8]) -> Result<Vec<u8>> {
        let cipher = Aes256Gcm::new(&self.key);
        let mut nonce_bytes = [0u8; 12];
        OsRng.fill_bytes(&mut nonce_bytes);
        let nonce = Nonce::from_slice(&nonce_bytes); // 96-bits; unique per message

        let ciphertext = cipher
            .encrypt(nonce, data)
            .map_err(|e| anyhow!("Encryption failed: {}", e))?;

        // Prepend nonce to ciphertext
        let mut result = nonce_bytes.to_vec();
        result.extend(ciphertext);
        Ok(result)
    }

    pub fn decrypt(&self, data: &[u8]) -> Result<Vec<u8>> {
        if data.len() < 12 {
            return Err(anyhow!("Data too short"));
        }

        let (nonce_bytes, ciphertext) = data.split_at(12);
        let nonce = Nonce::from_slice(nonce_bytes);
        let cipher = Aes256Gcm::new(&self.key);

        cipher
            .decrypt(nonce, ciphertext)
            .map_err(|e| anyhow!("Decryption failed: {}", e))
    }
}
