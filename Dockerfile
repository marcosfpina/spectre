# SPECTRE Fleet - Multi-stage Dockerfile
# Build: docker build -t spectre-proxy .
# Run:   docker run -p 3000:3000 -e JWT_SECRET=... spectre-proxy

# ── Build Stage ─────────────────────────────────────────────────────────────
FROM rust:bookworm AS builder

WORKDIR /build

# Copy workspace manifests first for layer caching
COPY Cargo.toml Cargo.lock ./
COPY crates/spectre-core/Cargo.toml crates/spectre-core/Cargo.toml
COPY crates/spectre-events/Cargo.toml crates/spectre-events/Cargo.toml
COPY crates/spectre-proxy/Cargo.toml crates/spectre-proxy/Cargo.toml
COPY crates/spectre-secrets/Cargo.toml crates/spectre-secrets/Cargo.toml
COPY crates/spectre-observability/Cargo.toml crates/spectre-observability/Cargo.toml

# Create dummy source files for dependency caching
RUN mkdir -p crates/spectre-core/src && echo "pub fn _dummy() {}" > crates/spectre-core/src/lib.rs && \
    mkdir -p crates/spectre-events/src && echo "pub fn _dummy() {}" > crates/spectre-events/src/lib.rs && \
    mkdir -p crates/spectre-proxy/src && echo "fn main() {}" > crates/spectre-proxy/src/main.rs && \
    mkdir -p crates/spectre-secrets/src && echo "pub fn _dummy() {}" > crates/spectre-secrets/src/lib.rs && \
    mkdir -p crates/spectre-observability/src && echo "pub fn _dummy() {}" > crates/spectre-observability/src/lib.rs

# Build dependencies only (cached layer)
RUN cargo build --release -p spectre-proxy 2>/dev/null || true

# Copy actual source code
COPY crates/ crates/

# Touch source files to invalidate the cache for the actual build
RUN touch crates/spectre-core/src/lib.rs \
    crates/spectre-events/src/lib.rs \
    crates/spectre-proxy/src/main.rs \
    crates/spectre-secrets/src/lib.rs \
    crates/spectre-observability/src/lib.rs

# Build the release binary
RUN cargo build --release -p spectre-proxy

# ── Runtime Stage ───────────────────────────────────────────────────────────
FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

RUN useradd -r -s /bin/false spectre

COPY --from=builder /build/target/release/spectre-proxy /usr/local/bin/spectre-proxy

USER spectre

EXPOSE 3000

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

ENTRYPOINT ["/usr/local/bin/spectre-proxy"]
