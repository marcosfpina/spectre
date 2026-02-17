# SPECTRE Framework - Architecture Decision Records

**Document Type**: Technical ADRs with Trade-Off Analysis
**Purpose**: Support informed decision-making for SPECTRE integration strategy
**Audience**: System Architect (kernelcore)
**Status**: Draft for Review
**Last Updated**: 2026-01-09

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [ADR-001: Phase 1 Project Integration Priority](#adr-001-phase-1-project-integration-priority)
3. [ADR-002: Service Integration Pattern](#adr-002-service-integration-pattern)
4. [ADR-003: Python Service Deployment Strategy](#adr-003-python-service-deployment-strategy)
5. [ADR-004: Secrets Management Architecture](#adr-004-secrets-management-architecture)
6. [ADR-005: LLM Request Routing Strategy](#adr-005-llm-request-routing-strategy)
7. [ADR-006: Observability Architecture](#adr-006-observability-architecture)
8. [ADR-007: Event Schema Versioning Strategy](#adr-007-event-schema-versioning-strategy)
9. [Project Prioritization Framework](#project-prioritization-framework)
10. [Integration Scenarios](#integration-scenarios)
11. [Risk Analysis](#risk-analysis)
12. [References](#references)

---

## Executive Summary

This document provides **rigorous trade-off analysis** for critical architectural decisions in the SPECTRE framework integration. Each ADR presents **3-4 viable alternatives** with quantitative and qualitative evaluation across 5 dimensions:

1. **Performance** (latency, throughput, resource usage)
2. **Maintainability** (code complexity, debugging, evolution)
3. **Complexity** (implementation effort, learning curve)
4. **Cost** (development time, operational overhead, cloud spend)
5. **Risk** (technical debt, failure modes, rollback difficulty)

**Key Principle**: This document presents **options, not prescriptions**. Final decisions rest with the architect based on business priorities and constraints.

---

## ADR-001: Phase 1 Project Integration Priority

### Context

Phase 1 (Security Infrastructure) requires choosing **1-2 projects** to integrate first. This decision establishes patterns for subsequent integrations and validates the event-driven architecture.

**Constraints**:
- Must complete within 2 weeks (Phase 1 timeline)
- Should demonstrate value quickly (proof of concept)
- Should validate core SPECTRE capabilities (event bus, proxy, secrets)

### Available Projects (Ranked by Maturity)

| Project | Maturity | Tech Stack | Integration Complexity | Value |
|---------|----------|------------|------------------------|-------|
| **securellm-bridge** | Production ✅ | Rust (Axum, TLS, audit) | Medium | High |
| **cognitive-vault** | Production ✅ | Rust+Go (FFI, crypto) | Low | Medium |
| **ml-offload-api** | Alpha 🚧 | Rust (Axum, NVIDIA) | Medium | High |
| **ai-agent-os** | Alpha 🚧 | Rust (6 crates, Hyprland) | High | Medium |
| **intelagent** | Alpha 🚧 | Rust (complex orchestration) | Very High | Very High |
| **ragtex** | Beta 🚧 | Python (LangChain, Vertex) | Medium | High |
| **arch-analyzer** | Beta 🚧 | Python (async, caching) | Low | Low |

### Alternative 1: Start with `cognitive-vault` (Conservative)

**Approach**: Extract crypto primitives from cognitive-vault into `spectre-secrets`

**Pros**:
- ✅ **Lowest complexity**: Crypto library extraction is straightforward
- ✅ **No external dependencies**: Self-contained Rust crate
- ✅ **Foundation for Phase 1**: Secrets management is prerequisite for proxy auth
- ✅ **Low risk**: Well-tested crypto stack (AES-256-GCM, Argon2id)

**Cons**:
- ❌ **Low immediate value**: Secrets alone don't demo end-to-end flows
- ❌ **No event bus validation**: Doesn't stress NATS architecture
- ❌ **Limited observability**: Secrets operations are infrequent

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 9/10 | In-memory crypto, no network I/O |
| Maintainability | 9/10 | Small, focused crate |
| Complexity | 10/10 | Direct code extraction |
| Cost | 10/10 | 2-3 days development |
| Risk | 10/10 | Proven crypto, no new patterns |

**Estimated Effort**: 2-3 days
**Risk Level**: Very Low
**Demo Value**: Low (internal component)

---

### Alternative 2: Start with `securellm-bridge` (Balanced)

**Approach**: Wrap securellm-bridge HTTP endpoints to publish NATS events, keep existing API

**Pros**:
- ✅ **High demo value**: End-to-end LLM request → response flow
- ✅ **Validates event bus**: Real-world request/reply pattern
- ✅ **Production-ready code**: Mature codebase with TLS, rate limiting, audit
- ✅ **FinOps integration**: Cost tracking already implemented
- ✅ **Clear success criteria**: Measure latency overhead (target: <50ms)

**Cons**:
- ❌ **Dual-write complexity**: Must maintain HTTP API + NATS simultaneously
- ❌ **Requires secrets management**: Needs API key rotation (dependency on cognitive-vault)
- ❌ **Performance overhead**: Additional hop through NATS (5-10ms latency)

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 7/10 | +5-10ms latency from NATS hop |
| Maintainability | 7/10 | Dual-write increases complexity |
| Complexity | 6/10 | HTTP→NATS bridge pattern new |
| Cost | 6/10 | 5-7 days development |
| Risk | 7/10 | Backward compatibility concerns |

**Estimated Effort**: 5-7 days
**Risk Level**: Medium
**Demo Value**: Very High (LLM requests demo'd)

---

### Alternative 3: Start with `ml-offload-api` (Aggressive)

**Approach**: Full NATS integration with VRAM monitoring events

**Pros**:
- ✅ **High technical value**: Validates hardware monitoring → event stream
- ✅ **FinOps critical**: Local inference cost = $0, major selling point
- ✅ **Unique capabilities**: VRAM-aware routing demonstrates intelligence
- ✅ **Event-rich**: Publishes many event types (VRAM, inference, cost)

**Cons**:
- ❌ **Hardware dependency**: Requires NVIDIA GPU (not in CI/CD)
- ❌ **Alpha maturity**: Less stable than securellm-bridge
- ❌ **Complex integration**: Model registry + backend abstraction
- ❌ **Testing challenges**: GPU mocking for unit tests

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 8/10 | Local inference, no API costs |
| Maintainability | 6/10 | Hardware-specific code complex |
| Complexity | 5/10 | GPU monitoring + NATS integration |
| Cost | 5/10 | 7-10 days development |
| Risk | 5/10 | Alpha code, hardware dependency |

**Estimated Effort**: 7-10 days
**Risk Level**: Medium-High
**Demo Value**: High (local AI demo'd)

---

### Alternative 4: Dual Integration - `cognitive-vault` + `securellm-bridge` (Recommended)

**Approach**:
1. Days 1-3: Extract crypto from cognitive-vault → spectre-secrets
2. Days 4-10: Integrate securellm-bridge with NATS events + spectre-secrets auth

**Pros**:
- ✅ **Complete Phase 1**: Both spectre-secrets and real integration
- ✅ **Sequential dependency**: Secrets ready before securellm needs it
- ✅ **High demo value**: End-to-end secure LLM gateway
- ✅ **Validates full stack**: Crypto, events, proxy, observability
- ✅ **Clear milestone**: Each sub-project has testable output

**Cons**:
- ❌ **Tight timeline**: 10 days for both (risk of scope creep)
- ❌ **Sequential risk**: Delay in secrets blocks securellm integration
- ❌ **Higher complexity**: Two integrations simultaneously

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 8/10 | Efficient crypto + acceptable NATS overhead |
| Maintainability | 8/10 | Two clean integrations |
| Complexity | 6/10 | Sequential execution reduces risk |
| Cost | 5/10 | 10 days total |
| Risk | 6/10 | Tight timeline but sequential dependencies |

**Estimated Effort**: 10 days (2 weeks)
**Risk Level**: Medium
**Demo Value**: Very High (secure LLM gateway with cost tracking)

---

### Recommendation Matrix

| Alternative | Effort | Risk | Demo Value | Strategic Fit | Overall Score |
|-------------|--------|------|------------|---------------|---------------|
| Alt 1: vault only | 2-3d | Very Low | Low | 6/10 | 6.5/10 |
| Alt 2: securellm | 5-7d | Medium | Very High | 9/10 | 8/10 |
| Alt 3: ml-offload | 7-10d | Medium-High | High | 8/10 | 7/10 |
| **Alt 4: vault + securellm** | **10d** | **Medium** | **Very High** | **10/10** | **8.5/10** ✅ |

### Recommended Decision: Alternative 4 (Dual Integration)

**Rationale**:
1. Completes entire Phase 1 scope (secrets + proxy validation)
2. Demonstrates complete value chain: secure request → LLM → cost tracking
3. Sequential execution reduces risk (secrets first, then securellm)
4. Fits 2-week Phase 1 timeline with buffer

**Decision Criteria for Architect**:
- If **timeline is critical** → Choose Alt 1 (cognitive-vault only)
- If **demo value paramount** → Choose Alt 2 (securellm-bridge)
- If **FinOps is priority** → Choose Alt 3 (ml-offload-api)
- If **complete Phase 1** → Choose Alt 4 (recommended)

**Success Metrics**:
- spectre-secrets: Encrypt/decrypt with <1ms latency, rotation in <5s
- securellm-bridge: NATS overhead <50ms p99, zero data loss
- Integration tests: 95% coverage, CI/CD green

---

## ADR-002: Service Integration Pattern

### Context

Domain services (Rust/Python) must integrate with SPECTRE event bus. The integration pattern affects **performance, maintainability, and evolution** of the architecture.

### Problem Statement

How should external services communicate with SPECTRE?

**Requirements**:
- Support both Rust and Python services
- Minimal latency overhead (<50ms p99)
- Backward compatibility with existing HTTP APIs
- Observable (request tracing, metrics)
- Testable (unit + integration tests)

### Alternative 1: Direct NATS Integration (Native Pattern)

**Approach**: Services directly use NATS client libraries

```rust
// Rust service
use spectre_events::EventBus;

#[tokio::main]
async fn main() {
    let bus = EventBus::connect("nats://localhost:4222").await?;
    let mut sub = bus.subscribe("llm.request.v1").await?;

    while let Some(msg) = sub.next().await {
        let response = handle_request(msg).await?;
        bus.publish(&response).await?;
    }
}
```

**Pros**:
- ✅ **Lowest latency**: Direct connection, no middleware
- ✅ **Simplest architecture**: No additional components
- ✅ **Best observability**: Native NATS tracing
- ✅ **Scales horizontally**: Queue groups for load balancing

**Cons**:
- ❌ **Requires code changes**: Must refactor existing services
- ❌ **No HTTP backward compatibility**: Breaking change for HTTP clients
- ❌ **Language-specific clients**: Different APIs for Rust vs Python

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 10/10 | No middleware, native NATS |
| Maintainability | 8/10 | Simple but requires refactor |
| Complexity | 7/10 | NATS learning curve |
| Cost | 7/10 | Refactor effort per service |
| Risk | 8/10 | Breaking changes for HTTP clients |

**Latency**: 5-10ms (NATS pub/sub)
**Effort**: Medium (per service refactor)
**Backward Compatibility**: ❌ None

---

### Alternative 2: HTTP Bridge Pattern (Hybrid)

**Approach**: Keep existing HTTP APIs, add NATS event publishing

```rust
// Existing HTTP handler
async fn handle_completion(req: ChatRequest) -> Result<ChatResponse> {
    // NEW: Publish event
    bus.publish(&Event::new(
        EventType::LlmRequest,
        service_id,
        serde_json::to_value(&req)?
    )).await?;

    // Existing logic
    let response = provider.complete(req).await?;

    // NEW: Publish response event
    bus.publish(&Event::new(
        EventType::LlmResponse,
        service_id,
        serde_json::to_value(&response)?
    )).await?;

    Ok(response)
}
```

**Pros**:
- ✅ **Backward compatible**: HTTP API unchanged
- ✅ **Incremental migration**: Can dual-write during transition
- ✅ **Low risk**: Existing clients unaffected
- ✅ **Observability added**: Events for monitoring without breaking API

**Cons**:
- ❌ **Dual-write complexity**: Maintain two interfaces
- ❌ **Event/HTTP inconsistency risk**: Can diverge over time
- ❌ **Performance overhead**: Serialize twice (HTTP + NATS)
- ❌ **Technical debt**: Eventually need to migrate away from HTTP

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 7/10 | +2-5ms for event publishing |
| Maintainability | 6/10 | Dual-write increases complexity |
| Complexity | 7/10 | Familiar HTTP + new events |
| Cost | 8/10 | Minimal refactor per service |
| Risk | 9/10 | Low risk, backward compatible |

**Latency**: HTTP baseline + 2-5ms
**Effort**: Low (add event publishing)
**Backward Compatibility**: ✅ Full

---

### Alternative 3: Sidecar Proxy Pattern (Enterprise)

**Approach**: Deploy `spectre-proxy` as sidecar, intercepts HTTP and publishes events

```
┌─────────────────────────────────────┐
│         Service Container            │
│  ┌────────────┐    ┌──────────────┐ │
│  │  Service   │───▶│   Sidecar    │ │
│  │  (HTTP)    │    │  spectre-    │ │
│  │            │◀───│  proxy       │ │
│  └────────────┘    └──────┬───────┘ │
│                            │         │
└────────────────────────────┼─────────┘
                             │
                             ▼
                       NATS Event Bus
```

**Pros**:
- ✅ **Zero code changes**: Service unaware of NATS
- ✅ **Polyglot support**: Works with any HTTP service
- ✅ **Centralized policy**: Auth, rate limiting in proxy
- ✅ **Ops-friendly**: Sidecar managed independently

**Cons**:
- ❌ **High complexity**: Requires Kubernetes/Docker Compose orchestration
- ❌ **Performance overhead**: Extra network hop (5-15ms)
- ❌ **Operational burden**: More containers to manage
- ❌ **Debugging harder**: Network issues obscured by sidecar

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 6/10 | +5-15ms from network hop |
| Maintainability | 7/10 | Centralized but more moving parts |
| Complexity | 4/10 | Sidecar orchestration complex |
| Cost | 5/10 | Infrastructure overhead |
| Risk | 6/10 | Network failure modes |

**Latency**: 5-15ms (localhost sidecar)
**Effort**: High (infrastructure setup)
**Backward Compatibility**: ✅ Full

---

### Alternative 4: Subprocess Wrapper Pattern (Simple)

**Approach**: SPECTRE spawns services as subprocesses, captures stdio events

```rust
// spectre-orchestrator
let mut child = Command::new("python")
    .arg("ragtex/main.py")
    .stdin(Stdio::piped())
    .stdout(Stdio::piped())
    .spawn()?;

// Send request via stdin
writeln!(child.stdin, "{}", request_json)?;

// Read response from stdout
let response = BufReader::new(child.stdout).lines().next()?;
bus.publish(&Event::new(EventType::RagResponse, service_id, response)).await?;
```

**Pros**:
- ✅ **Simplest integration**: No service code changes
- ✅ **Language agnostic**: Works with any executable
- ✅ **Process isolation**: Crashes don't affect SPECTRE

**Cons**:
- ❌ **Poor performance**: Process spawn overhead (50-100ms)
- ❌ **Limited scalability**: Can't horizontally scale
- ❌ **No request-reply**: Async only (can't handle sync requests well)
- ❌ **Debugging nightmare**: Stdio piping fragile

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 3/10 | 50-100ms process spawn |
| Maintainability | 5/10 | Simple but fragile |
| Complexity | 8/10 | Just spawn processes |
| Cost | 9/10 | No integration code needed |
| Risk | 4/10 | Process management issues |

**Latency**: 50-100ms (process spawn)
**Effort**: Very Low
**Backward Compatibility**: ✅ Full

---

### Recommendation Matrix

| Pattern | Performance | Maintainability | Complexity | Cost | Risk | Overall |
|---------|-------------|-----------------|------------|------|------|---------|
| Native NATS | 10/10 | 8/10 | 7/10 | 7/10 | 8/10 | 8/10 ✅ |
| HTTP Bridge | 7/10 | 6/10 | 7/10 | 8/10 | 9/10 | 7.4/10 |
| Sidecar Proxy | 6/10 | 7/10 | 4/10 | 5/10 | 6/10 | 5.6/10 |
| Subprocess | 3/10 | 5/10 | 8/10 | 9/10 | 4/10 | 5.8/10 |

### Recommended Decision: Hybrid Approach

**Phase 1-2 (Short-term)**: Use **HTTP Bridge Pattern** for initial integration
- Minimal disruption, backward compatible
- Validate event schemas and observability

**Phase 3+ (Long-term)**: Migrate to **Native NATS Integration**
- Optimal performance and simplicity
- Remove HTTP dual-write technical debt

**Rationale**:
- De-risks Phase 1 with incremental approach
- Allows validating event patterns before full commitment
- Provides clear migration path

**Decision Criteria**:
- If **performance critical** → Use Native NATS immediately
- If **backward compat critical** → Use HTTP Bridge
- If **polyglot at scale** → Use Sidecar Proxy
- If **quick prototype** → Use Subprocess (temp only)

---

## ADR-003: Python Service Deployment Strategy

### Context

Two Python services exist: `ragtex` (RAG system) and `arch-analyzer` (NixOS analysis). They must integrate with Rust-based SPECTRE infrastructure.

### Problem Statement

How should Python services be deployed and managed?

**Requirements**:
- Support async Python (asyncio)
- Integrate with NATS event bus
- Reproducible deployments
- Observable and debuggable
- Cost-effective (no unnecessary Docker overhead)

### Alternative 1: Docker Containers (Industry Standard)

**Approach**: Containerize Python services with nats-py client

```dockerfile
# Dockerfile
FROM python:3.13-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "main.py"]
```

```yaml
# docker-compose.yml
services:
  ragtex:
    build: ~/dev/low-level/ragtex
    environment:
      - NATS_URL=nats://nats:4222
    depends_on:
      - nats
```

**Pros**:
- ✅ **Industry standard**: Well-understood pattern
- ✅ **Isolation**: Dependencies don't conflict
- ✅ **Portability**: Runs anywhere Docker runs
- ✅ **Resource limits**: Can cap CPU/memory via Docker

**Cons**:
- ❌ **Overhead**: 50-100MB per container + startup time
- ❌ **Dev friction**: Rebuild image on every code change
- ❌ **Debugging harder**: Need to exec into container
- ❌ **Not Nix-native**: Doesn't leverage NixOS reproducibility

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 7/10 | Container overhead minimal |
| Maintainability | 8/10 | Standard tooling |
| Complexity | 7/10 | Docker learning curve |
| Cost | 7/10 | Disk space + build time |
| Risk | 9/10 | Proven pattern |

**Resource Usage**: ~100MB RAM per service
**Startup Time**: 2-5 seconds
**Development Friction**: Medium (rebuild on changes)

---

### Alternative 2: Nix Flake + systemd Service (NixOS Native) ⭐

**Approach**: Define Python environment in flake.nix, run as systemd service

```nix
# ragtex/flake.nix
{
  outputs = { self, nixpkgs }: {
    packages.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.python3Packages.buildPythonApplication {
      pname = "ragtex";
      version = "0.1.0";
      src = ./.;
      propagatedBuildInputs = with nixpkgs.legacyPackages.x86_64-linux.python3Packages; [
        nats-py
        langchain
        # ...
      ];
    };

    nixosModules.ragtex = { config, lib, pkgs, ... }: {
      systemd.services.ragtex = {
        description = "RAGTeX NATS Service";
        wantedBy = [ "multi-user.target" ];
        after = [ "nats.service" ];
        serviceConfig = {
          ExecStart = "${self.packages.x86_64-linux.default}/bin/ragtex";
          Restart = "always";
          Environment = "NATS_URL=nats://localhost:4222";
        };
      };
    };
  };
}
```

**Pros**:
- ✅ **Nix-native**: Leverages NixOS declarative config
- ✅ **Zero overhead**: Native process, no container
- ✅ **Reproducible**: Exact dependencies via Nix
- ✅ **systemd integration**: Logs via journalctl, auto-restart

**Cons**:
- ❌ **NixOS-specific**: Won't work on non-NixOS systems
- ❌ **Learning curve**: Nix ecosystem complex
- ❌ **Slower builds**: Nix builds can be slow initially

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 10/10 | Native process, no overhead |
| Maintainability | 9/10 | Declarative, version-controlled |
| Complexity | 6/10 | Nix learning curve steep |
| Cost | 9/10 | No container overhead |
| Risk | 7/10 | NixOS-specific, less portable |

**Resource Usage**: ~30MB RAM (native Python)
**Startup Time**: <1 second
**Development Friction**: Low (nix develop)

---

### Alternative 3: Embedded PyO3 (Rust-Python Bridge)

**Approach**: Embed Python interpreter in Rust using PyO3

```rust
// spectre-python-bridge/src/lib.rs
use pyo3::prelude::*;

pub fn run_ragtex(query: &str) -> PyResult<String> {
    Python::with_gil(|py| {
        let ragtex = PyModule::import(py, "ragtex")?;
        let result = ragtex.getattr("query")?.call1((query,))?;
        result.extract()
    })
}
```

**Pros**:
- ✅ **Single binary**: No separate deployment
- ✅ **Low latency**: No IPC overhead
- ✅ **Type safety**: Rust types at boundary

**Cons**:
- ❌ **GIL contention**: Python Global Interpreter Lock limits parallelism
- ❌ **Crash risk**: Python crash kills Rust process
- ❌ **Complex builds**: PyO3 + Python deps in Nix
- ❌ **Debugging nightmare**: Mixed-language stack traces

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 6/10 | GIL limits concurrency |
| Maintainability | 4/10 | Very complex to debug |
| Complexity | 3/10 | PyO3 + build complexity high |
| Cost | 5/10 | High initial effort |
| Risk | 4/10 | Crash isolation poor |

**Resource Usage**: Shared with Rust process
**Startup Time**: Instant (already embedded)
**Development Friction**: Very High

---

### Alternative 4: Hybrid - Docker for Python, Native for Rust

**Approach**: Python services in Docker, Rust services native

```yaml
# docker-compose.yml
services:
  # Python services (Docker)
  ragtex:
    build: ~/dev/low-level/ragtex
    networks: [spectre-net]

  arch-analyzer:
    build: ~/dev/low-level/arch-analyzer
    networks: [spectre-net]

  # Rust services (native systemd)
  # Managed by NixOS configuration.nix
```

**Pros**:
- ✅ **Best of both worlds**: Docker where it makes sense, native for Rust
- ✅ **Pragmatic**: Doesn't force Nix on Python devs
- ✅ **Flexible**: Can migrate Python to Nix later

**Cons**:
- ❌ **Inconsistent**: Two deployment methods to maintain
- ❌ **Docker still required**: Can't eliminate Docker entirely

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 8/10 | Rust native + acceptable Python overhead |
| Maintainability | 7/10 | Two systems to maintain |
| Complexity | 6/10 | Manageable split |
| Cost | 8/10 | Good pragmatic balance |
| Risk | 8/10 | Standard patterns for each |

---

### Recommendation Matrix

| Alternative | Performance | Maintainability | Complexity | Cost | Risk | Overall |
|-------------|-------------|-----------------|------------|------|------|---------|
| Docker | 7/10 | 8/10 | 7/10 | 7/10 | 9/10 | 7.6/10 |
| **Nix + systemd** | **10/10** | **9/10** | **6/10** | **9/10** | **7/10** | **8.2/10** ✅ |
| PyO3 Embedded | 6/10 | 4/10 | 3/10 | 5/10 | 4/10 | 4.4/10 |
| Hybrid | 8/10 | 7/10 | 6/10 | 8/10 | 8/10 | 7.4/10 |

### Recommended Decision: Nix + systemd (Alternative 2)

**Rationale**:
1. **NixOS-native**: You're already on NixOS, leverage it fully
2. **Best performance**: Native processes, no container overhead
3. **Declarative**: Entire stack in configuration.nix
4. **Reproducible**: Exact versions pinned in flake.lock

**Migration Path**:
- **Phase 1**: Start with Docker (faster to prototype)
- **Phase 2**: Migrate to Nix+systemd once patterns validated

**Decision Criteria**:
- If **NixOS environment** → Use Nix + systemd (recommended)
- If **need portability** → Use Docker
- If **single binary important** → Consider PyO3 (carefully)
- If **mixed team** → Use Hybrid approach

---

## ADR-004: Secrets Management Architecture

### Context

SPECTRE requires secure credential storage and automatic rotation for:
- LLM API keys (OpenAI, Anthropic, Vertex AI)
- Database passwords (TimescaleDB, Neo4j)
- Service authentication tokens
- TLS certificates

**Existing Asset**: `cognitive-vault` has production-ready crypto (AES-256-GCM, Argon2id)

### Problem Statement

Should we extract cognitive-vault crypto into spectre-secrets, or integrate vault directly?

### Alternative 1: Extract Crypto Library (Minimal)

**Approach**: Copy crypto primitives from cognitive-vault into spectre-secrets

```rust
// spectre-secrets/src/crypto.rs (extracted)
pub struct CryptoEngine {
    key: SecretKey,
}

impl CryptoEngine {
    pub fn new(password: &str, salt: &[u8]) -> Result<Self> {
        let key = argon2_derive_key(password, salt)?;
        Ok(Self { key })
    }

    pub fn encrypt(&self, plaintext: &[u8]) -> Result<Vec<u8>> {
        aes_gcm_encrypt(&self.key, plaintext)
    }

    pub fn decrypt(&self, ciphertext: &[u8]) -> Result<Vec<u8>> {
        aes_gcm_decrypt(&self.key, ciphertext)
    }
}
```

**Pros**:
- ✅ **Clean separation**: No dependency on cognitive-vault crate
- ✅ **SPECTRE-specific**: Can optimize for SPECTRE use case
- ✅ **No FFI**: Pure Rust, no Go dependencies

**Cons**:
- ❌ **Code duplication**: cognitive-vault and spectre-secrets diverge
- ❌ **Security risk**: Might miss security updates in cognitive-vault
- ❌ **Lost features**: cognitive-vault has CLI, backup, etc.

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 10/10 | Optimized for SPECTRE |
| Maintainability | 6/10 | Code duplication |
| Complexity | 8/10 | Simple extraction |
| Cost | 8/10 | 2-3 days extraction |
| Risk | 7/10 | Security divergence risk |

**Effort**: 2-3 days
**Ongoing Maintenance**: Medium (sync security fixes)

---

### Alternative 2: Depend on cognitive-vault Crate (DRY)

**Approach**: Add cognitive-vault as Git dependency

```toml
# spectre-secrets/Cargo.toml
[dependencies]
vault_core = { git = "https://github.com/kernelcore/cognitive-vault", branch = "main" }
```

**Pros**:
- ✅ **No duplication**: Single source of truth
- ✅ **Automatic updates**: Benefit from cognitive-vault improvements
- ✅ **Proven code**: Battle-tested crypto

**Cons**:
- ❌ **External dependency**: SPECTRE depends on separate repo
- ❌ **Version coupling**: Breaking changes in vault break SPECTRE
- ❌ **Go FFI complexity**: Brings Go build into SPECTRE (if using CLI)

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 10/10 | Same as extraction |
| Maintainability | 9/10 | DRY principle |
| Complexity | 7/10 | External dependency management |
| Cost | 10/10 | Minimal integration work |
| Risk | 6/10 | Coupling to external repo |

**Effort**: 1 day integration
**Ongoing Maintenance**: Low (upstream does work)

---

### Alternative 3: Secrets Service Pattern (Microservice)

**Approach**: Run cognitive-vault as separate NATS service

```
Client → NATS secrets.retrieve.v1 → cognitive-vault service → NATS secrets.response.v1 → Client
```

**Pros**:
- ✅ **Loose coupling**: cognitive-vault evolves independently
- ✅ **Centralized secrets**: Single service manages all credentials
- ✅ **Polyglot access**: Any language can request secrets via NATS

**Cons**:
- ❌ **Network latency**: +5-10ms per secret retrieval
- ❌ **Single point of failure**: If vault down, all services blocked
- ❌ **Operational overhead**: Another service to deploy/monitor

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 6/10 | Network round-trip overhead |
| Maintainability | 8/10 | Clean separation |
| Complexity | 6/10 | Service orchestration |
| Cost | 7/10 | 4-5 days integration |
| Risk | 5/10 | Single point of failure |

**Effort**: 4-5 days
**Ongoing Maintenance**: Medium (service management)

---

### Alternative 4: Hybrid - Extract Crypto, Keep CLI Separate

**Approach**:
1. Create `spectre-crypto` lib crate (extracted primitives)
2. cognitive-vault CLI uses `spectre-crypto` (shared library)
3. spectre-secrets uses `spectre-crypto` directly

```
┌──────────────────────────┐
│   spectre-crypto (lib)   │  ← Shared crypto primitives
└───────────┬──────────────┘
            │
     ┌──────┴──────┐
     │             │
     ▼             ▼
┌─────────┐  ┌────────────────┐
│ spectre-│  │ cognitive-vault│
│ secrets │  │ CLI (Go FFI)   │
└─────────┘  └────────────────┘
```

**Pros**:
- ✅ **Best of both worlds**: Shared crypto, independent tools
- ✅ **No duplication**: Both use same library
- ✅ **Backward compat**: cognitive-vault CLI unchanged

**Cons**:
- ❌ **Refactor cognitive-vault**: Needs restructuring
- ❌ **More crates**: Adds `spectre-crypto` to workspace

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 10/10 | Direct library access |
| Maintainability | 9/10 | Shared code, clear boundaries |
| Complexity | 6/10 | Requires refactoring |
| Cost | 6/10 | 5-6 days refactor + integration |
| Risk | 8/10 | Clean architecture |

**Effort**: 5-6 days
**Ongoing Maintenance**: Low (shared crate)

---

### Recommendation Matrix

| Alternative | Performance | Maintainability | Complexity | Cost | Risk | Overall |
|-------------|-------------|-----------------|------------|------|------|---------|
| Extract Crypto | 10/10 | 6/10 | 8/10 | 8/10 | 7/10 | 7.8/10 |
| Depend on Vault | 10/10 | 9/10 | 7/10 | 10/10 | 6/10 | 8.4/10 |
| Secrets Service | 6/10 | 8/10 | 6/10 | 7/10 | 5/10 | 6.4/10 |
| **Hybrid (Shared Lib)** | **10/10** | **9/10** | **6/10** | **6/10** | **8/10** | **7.8/10** ✅ |

### Recommended Decision: Hybrid Approach (Alternative 4)

**Phase 1 (Quick Start)**: Use Alternative 2 (Depend on vault_core)
- Fast integration (1 day)
- Validate secrets management patterns

**Phase 2 (Long-term)**: Refactor to Alternative 4 (Shared Lib)
- Extract `spectre-crypto` crate
- Both SPECTRE and cognitive-vault use it

**Rationale**:
1. **De-risks Phase 1**: Get secrets working quickly
2. **Future-proof**: Shared library is clean long-term architecture
3. **Incremental**: Can refactor after validating patterns

**Decision Criteria**:
- If **time critical** → Use Alt 2 (depend on vault)
- If **long-term architecture** → Use Alt 4 (shared lib)
- If **polyglot important** → Consider Alt 3 (service)

---

## ADR-005: LLM Request Routing Strategy

### Context

Multiple LLM providers available:
- **Vertex AI** (Gemini) - Cloud, powerful, expensive ($0.05-0.20 per request)
- **ml-offload-api** (llama.cpp) - Local, fast, free, limited by VRAM
- **securellm-bridge** (OpenAI/DeepSeek/Anthropic) - Proxy with unified API

**Goal**: Minimize cost (FinOps) while maintaining quality

### Problem Statement

How should SPECTRE route LLM requests to optimize cost vs quality?

### Alternative 1: Simple Priority (Local-First)

**Approach**: Try local first, failover to cloud

```rust
async fn route_llm_request(req: LlmRequest) -> Result<LlmResponse> {
    // Try ml-offload-api (local, free)
    match ml_offload.complete(req.clone()).await {
        Ok(response) => return Ok(response),
        Err(VramExhausted) => {
            // Failover to Vertex AI
            return vertex_ai.complete(req).await;
        }
    }
}
```

**Pros**:
- ✅ **Maximizes cost savings**: Local inference free
- ✅ **Simple logic**: Easy to understand
- ✅ **Fast for simple queries**: Local has lower latency

**Cons**:
- ❌ **Quality issues**: Local models less capable for complex tasks
- ❌ **No load balancing**: All requests hit local until exhausted
- ❌ **No quality feedback**: Can't learn from failures

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 8/10 | Local fast, cloud slower |
| Maintainability | 9/10 | Simple code |
| Complexity | 9/10 | Trivial logic |
| Cost | 9/10 | Maximal local usage |
| Risk | 6/10 | Quality unpredictable |

**Cost Savings**: ~80% (if local handles 80% of requests)
**Latency**: Local 100-500ms, Cloud 1-3s
**Quality**: Variable

---

### Alternative 2: Intelligent Routing (Complexity-Based)

**Approach**: Route based on request complexity

```rust
async fn route_llm_request(req: LlmRequest) -> Result<LlmResponse> {
    let complexity = analyze_complexity(&req);

    match complexity {
        Complexity::Simple => ml_offload.complete(req).await,
        Complexity::Moderate if ml_offload.vram_available() > 2GB => {
            ml_offload.complete(req).await
        },
        Complexity::Moderate | Complexity::Complex => {
            vertex_ai.complete(req).await
        }
    }
}

fn analyze_complexity(req: &LlmRequest) -> Complexity {
    if req.prompt.len() > 2000 { return Complexity::Complex; }
    if req.requires_reasoning { return Complexity::Complex; }
    if req.context_length > 8000 { return Complexity::Moderate; }
    Complexity::Simple
}
```

**Pros**:
- ✅ **Cost-quality balance**: Routes appropriately
- ✅ **VRAM-aware**: Checks availability before routing
- ✅ **Measurable**: Can track routing decisions

**Cons**:
- ❌ **Heuristic tuning**: analyze_complexity() needs calibration
- ❌ **More complex**: Additional logic to maintain
- ❌ **False positives**: May route simple tasks to cloud unnecessarily

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 9/10 | Optimal latency per complexity |
| Maintainability | 7/10 | Heuristics need tuning |
| Complexity | 6/10 | Non-trivial routing logic |
| Cost | 8/10 | Good balance (60-70% local) |
| Risk | 7/10 | Heuristics can be wrong |

**Cost Savings**: ~60-70%
**Latency**: Optimized per complexity
**Quality**: High (complex → cloud)

---

### Alternative 3: ML-Based Routing (Advanced)

**Approach**: Train small classifier to predict best provider

```rust
async fn route_llm_request(req: LlmRequest) -> Result<LlmResponse> {
    let features = extract_features(&req); // prompt length, keywords, etc.
    let prediction = routing_model.predict(features); // local vs cloud

    match prediction {
        Provider::Local => ml_offload.complete(req).await,
        Provider::Cloud => vertex_ai.complete(req).await,
    }
}

// Background task: Train model on historical requests
async fn train_routing_model() {
    let history = load_historical_requests().await;
    let labels = history.iter().map(|r| {
        if r.local_succeeded && r.quality_score > 0.8 { Provider::Local }
        else { Provider::Cloud }
    });
    routing_model.train(history, labels).await;
}
```

**Pros**:
- ✅ **Optimal routing**: Learns from data
- ✅ **Adaptive**: Improves over time
- ✅ **Cost-aware**: Can optimize for cost vs quality tradeoff

**Cons**:
- ❌ **High complexity**: Requires ML pipeline (training, inference)
- ❌ **Cold start problem**: Needs historical data
- ❌ **Operational overhead**: Model training, versioning, deployment

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 10/10 | Optimal learned routing |
| Maintainability | 5/10 | ML pipeline complex |
| Complexity | 3/10 | Requires ML infrastructure |
| Cost | 9/10 | Best cost optimization |
| Risk | 5/10 | Model drift, cold start issues |

**Cost Savings**: ~70-80% (optimal learned)
**Latency**: Optimized
**Quality**: High (learned from feedback)

---

### Alternative 4: Cost-Capped Round Robin

**Approach**: Use local until daily cost budget, then round-robin cloud

```rust
async fn route_llm_request(req: LlmRequest) -> Result<LlmResponse> {
    if daily_cloud_cost() < DAILY_BUDGET {
        // Still in budget, prefer cloud for quality
        return vertex_ai.complete(req).await;
    }

    // Over budget, use local only
    ml_offload.complete(req).await
}
```

**Pros**:
- ✅ **Budget guarantee**: Never exceed cost
- ✅ **Simple logic**: Easy to implement
- ✅ **Quality-first**: Uses cloud while budget allows

**Cons**:
- ❌ **End-of-day degradation**: All local at month-end
- ❌ **No optimization**: Doesn't minimize cost intelligently
- ❌ **Poor UX**: Quality drops suddenly when budget hit

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 7/10 | Cloud until budget, then local |
| Maintainability | 9/10 | Simple budget check |
| Complexity | 9/10 | Trivial logic |
| Cost | 7/10 | Guarantees budget but not optimal |
| Risk | 6/10 | Poor UX at budget limit |

**Cost Savings**: Fixed by budget
**Latency**: Cloud baseline until budget
**Quality**: High until budget, then degrades

---

### Recommendation Matrix

| Alternative | Performance | Maintainability | Complexity | Cost | Risk | Overall |
|-------------|-------------|-----------------|------------|------|------|---------|
| Local-First | 8/10 | 9/10 | 9/10 | 9/10 | 6/10 | 8.2/10 |
| **Intelligent Routing** | **9/10** | **7/10** | **6/10** | **8/10** | **7/10** | **7.4/10** ✅ |
| ML-Based | 10/10 | 5/10 | 3/10 | 9/10 | 5/10 | 6.4/10 |
| Cost-Capped | 7/10 | 9/10 | 9/10 | 7/10 | 6/10 | 7.6/10 |

### Recommended Decision: Phased Approach

**Phase 1 (Immediate)**: Start with Alternative 1 (Local-First)
- Simple, fast to implement
- Validate cost savings hypothesis

**Phase 2 (Month 2)**: Upgrade to Alternative 2 (Intelligent Routing)
- Add complexity heuristics
- Measure cost vs quality tradeoff

**Phase 3 (Future)**: Consider Alternative 3 (ML-Based) if data justifies
- Only if historical data shows clear patterns
- Requires dedicated ML engineer

**Rationale**:
1. **Incremental complexity**: Start simple, add sophistication based on data
2. **Data-driven**: Phase 1 generates data to inform Phase 2 heuristics
3. **Risk mitigation**: Avoid premature optimization (ML-based routing)

**Decision Criteria**:
- If **cost paramount** → Use Alt 1 (local-first) aggressively
- If **quality paramount** → Use Alt 4 (cost-capped) with high budget
- If **balanced** → Use Alt 2 (intelligent routing) ✅
- If **ML expertise available** → Consider Alt 3 long-term

---

## ADR-006: Observability Architecture

### Context

SPECTRE must provide:
- Real-time metrics (request latency, throughput, error rates)
- Cost tracking (per service, per user, per request)
- Distributed tracing (correlation IDs across services)
- Anomaly detection (ML-based alerts)
- Dependency visualization (service graph)

**Infrastructure Available**: TimescaleDB (time-series), Neo4j (graph), NATS (event stream)

### Problem Statement

How should observability data flow through the system?

### Alternative 1: Centralized Collector (Simple)

**Approach**: Single `spectre-observability` service subscribes to all events

```
All Services → NATS (wildcard *.*.v1) → spectre-observability → TimescaleDB/Neo4j
```

**Pros**:
- ✅ **Simple architecture**: One service handles all observability
- ✅ **Centralized logic**: Anomaly detection in one place
- ✅ **Easy to reason about**: Clear data flow

**Cons**:
- ❌ **Single point of failure**: If observability down, lose all metrics
- ❌ **Bottleneck**: All events funnel through one service
- ❌ **Scaling challenges**: Hard to horizontally scale

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 7/10 | Potential bottleneck at scale |
| Maintainability | 9/10 | Simple, single service |
| Complexity | 9/10 | Straightforward |
| Cost | 9/10 | Low operational overhead |
| Risk | 6/10 | Single point of failure |

**Throughput**: ~10K events/sec (single instance)
**Latency**: 5-10ms (async processing)
**Operational Complexity**: Low

---

### Alternative 2: Distributed Collectors (Scalable)

**Approach**: Multiple observability workers with queue groups

```
All Services → NATS (wildcard) → [Collector 1, Collector 2, Collector 3] → Databases
                                   (Queue Group: load balanced)
```

**Pros**:
- ✅ **Horizontal scaling**: Add workers as load increases
- ✅ **High availability**: Workers can fail without data loss
- ✅ **Load balanced**: NATS queue groups distribute work

**Cons**:
- ❌ **Consistency challenges**: Multiple writers to databases
- ❌ **More complex**: Worker coordination needed
- ❌ **Anomaly detection harder**: State distributed across workers

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 10/10 | Linear scaling with workers |
| Maintainability | 7/10 | Worker coordination complexity |
| Complexity | 6/10 | Distributed system challenges |
| Cost | 7/10 | More infrastructure |
| Risk | 8/10 | Better fault tolerance |

**Throughput**: ~100K events/sec (10 workers)
**Latency**: 5-10ms (unchanged)
**Operational Complexity**: Medium

---

### Alternative 3: Embedded Observability (Performance)

**Approach**: Each service writes directly to TimescaleDB/Neo4j

```
Each Service → TimescaleDB (metrics) + Neo4j (dependencies) directly
            → NATS (for real-time dashboard only)
```

**Pros**:
- ✅ **Lowest latency**: No intermediary
- ✅ **No SPOF**: Observability failures don't cascade
- ✅ **Simple per service**: Each service manages own metrics

**Cons**:
- ❌ **Tight coupling**: Services depend on observability DBs
- ❌ **Credentials everywhere**: Every service needs DB passwords
- ❌ **Anomaly detection fragmented**: No central view

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 10/10 | Direct writes, no middleware |
| Maintainability | 5/10 | Fragmented, tight coupling |
| Complexity | 6/10 | Every service has DB logic |
| Cost | 8/10 | No observability service |
| Risk | 5/10 | Coupling risk high |

**Throughput**: Limited by DB capacity
**Latency**: 1-2ms (direct write)
**Operational Complexity**: High (credentials mgmt)

---

### Alternative 4: Hybrid - Central Collector + Service-Level Caching

**Approach**: Services emit events, observability caches hot metrics

```
Services → NATS → spectre-observability (caches hot metrics in Redis) → TimescaleDB
                                        ↓
                                   Real-time Dashboard (reads from Redis)
```

**Pros**:
- ✅ **Real-time dashboard**: Hot metrics in Redis (ms latency)
- ✅ **Historical analysis**: Full data in TimescaleDB
- ✅ **Decoupled**: Services don't know about observability storage

**Cons**:
- ❌ **Redis dependency**: Another component to manage
- ❌ **Cache consistency**: Hot vs cold data can diverge
- ❌ **More complex**: Two storage tiers

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 9/10 | Redis for hot data, DB for cold |
| Maintainability | 7/10 | Two-tier storage |
| Complexity | 6/10 | Cache invalidation complexity |
| Cost | 7/10 | Redis + TimescaleDB |
| Risk | 7/10 | Cache consistency risks |

**Throughput**: ~50K events/sec
**Latency**: <1ms (Redis reads), 10ms (DB writes)
**Operational Complexity**: Medium

---

### Recommendation Matrix

| Alternative | Performance | Maintainability | Complexity | Cost | Risk | Overall |
|-------------|-------------|-----------------|------------|------|------|---------|
| **Centralized** | **7/10** | **9/10** | **9/10** | **9/10** | **6/10** | **8/10** ✅ |
| Distributed | 10/10 | 7/10 | 6/10 | 7/10 | 8/10 | 7.6/10 |
| Embedded | 10/10 | 5/10 | 6/10 | 8/10 | 5/10 | 6.8/10 |
| Hybrid Cache | 9/10 | 7/10 | 6/10 | 7/10 | 7/10 | 7.2/10 |

### Recommended Decision: Start Centralized, Scale to Distributed

**Phase 1-2**: Use Alternative 1 (Centralized Collector)
- Simplest to implement and debug
- Sufficient for initial load (< 10K events/sec)
- Single service to monitor

**Phase 3+**: Migrate to Alternative 2 (Distributed Collectors) if needed
- Only if load exceeds 10K events/sec
- Horizontal scaling when necessary

**Rationale**:
1. **YAGNI**: Don't optimize for scale you don't have yet
2. **Incremental**: Easy migration path (just add workers)
3. **Data-driven**: Phase 1 will reveal actual load

**Decision Criteria**:
- If **load < 10K events/sec** → Use Alt 1 (centralized) ✅
- If **load > 10K events/sec** → Use Alt 2 (distributed)
- If **real-time dashboard critical** → Consider Alt 4 (hybrid cache)
- If **zero observability overhead** → Consider Alt 3 (embedded)

---

## ADR-007: Event Schema Versioning Strategy

### Context

Event schemas will evolve over time. Breaking changes must not disrupt services.

### Problem Statement

How to handle event schema evolution?

### Alternative 1: Semantic Versioning in Subject

**Approach**: Include version in NATS subject

```
llm.request.v1  → Current production
llm.request.v2  → New version with breaking changes
```

**Migration**: Services subscribe to both during transition

```rust
// Publisher (new)
bus.publish("llm.request.v2", new_schema).await;

// Subscriber (during migration)
let mut sub_v1 = bus.subscribe("llm.request.v1").await?;
let mut sub_v2 = bus.subscribe("llm.request.v2").await?;
tokio::select! {
    msg = sub_v1.next() => handle_v1(msg),
    msg = sub_v2.next() => handle_v2(msg),
}
```

**Pros**:
- ✅ **Explicit versioning**: Clear which version used
- ✅ **Backward compatible**: Old services keep working
- ✅ **Gradual migration**: Can dual-subscribe during transition

**Cons**:
- ❌ **Subject proliferation**: Many v1/v2/v3 subjects
- ❌ **Cleanup burden**: Must deprecate old versions

**Recommended**: ✅ This is the standard approach

---

## Project Prioritization Framework

### Evaluation Matrix

| Project | Maturity | Complexity | Value | Risk | Dependencies | Priority Score |
|---------|----------|------------|-------|------|--------------|----------------|
| **cognitive-vault** | 10/10 | 2/10 | 6/10 | 2/10 | None | **7.5/10** 🥇 |
| **securellm-bridge** | 10/10 | 6/10 | 10/10 | 4/10 | vault (auth) | **7.2/10** 🥈 |
| **ml-offload-api** | 6/10 | 6/10 | 9/10 | 6/10 | GPU hardware | **6.0/10** 🥉 |
| **ragtex** | 7/10 | 5/10 | 8/10 | 5/10 | Vertex AI | **5.8/10** |
| **arch-analyzer** | 7/10 | 3/10 | 4/10 | 3/10 | None | **5.0/10** |
| **ai-agent-os** | 6/10 | 7/10 | 5/10 | 5/10 | Hyprland (opt) | **4.8/10** |
| **intelagent** | 6/10 | 10/10 | 10/10 | 8/10 | DAO, ZK circuits | **4.4/10** |

### Scoring Methodology

**Maturity** (10 = production, 0 = prototype):
- Code quality, test coverage, documentation
- Production usage history

**Complexity** (10 = trivial, 0 = very complex):
- Integration effort (person-days)
- Dependencies and prerequisites

**Value** (10 = critical, 0 = nice-to-have):
- Business impact
- Architectural demonstration value

**Risk** (10 = no risk, 0 = high risk):
- Technical debt
- Failure blast radius
- Rollback difficulty

**Priority Score**: Weighted average (Maturity: 30%, Complexity: 20%, Value: 30%, Risk: 20%)

---

## Integration Scenarios

### Scenario A: Conservative (Low Risk)

**Timeline**: 4 weeks
**Projects**: cognitive-vault → arch-analyzer → ai-agent-os

**Rationale**:
- Start with simplest integrations
- Build confidence before complex projects
- Minimal external dependencies

**Pros**: Low risk, steady progress
**Cons**: Low demo value early

---

### Scenario B: Balanced (Recommended) ✅

**Timeline**: 6 weeks
**Projects**: cognitive-vault + securellm-bridge → ml-offload-api → ragtex

**Rationale**:
- Phase 1: Secrets + LLM gateway (high value)
- Phase 2: Local inference (cost savings demo)
- Phase 3: RAG system (AI capabilities)

**Pros**: Good balance of risk and value
**Cons**: Moderate complexity

---

### Scenario C: Aggressive (High Value)

**Timeline**: 8 weeks
**Projects**: cognitive-vault + securellm-bridge → intelagent → ml-offload-api

**Rationale**:
- Tackle most valuable project (intelagent) early
- Accept higher risk for higher reward
- DAO governance showcases innovation

**Pros**: Maximum value demonstrated
**Cons**: High complexity, technical risk

---

## Risk Analysis

### Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| NATS performance bottleneck | Low | High | Load test Phase 0, distributed collectors |
| Event schema changes break services | Medium | Medium | Semantic versioning (ADR-007) |
| Python NATS integration issues | Medium | Low | Prototype with nats-py early |
| cognitive-vault crypto bugs | Low | Critical | Extensive security audit + testing |
| GPU availability (ml-offload) | High | Medium | Fallback to cloud (Vertex AI) |

### Schedule Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Phase 1 overruns 2 weeks | Medium | Medium | Reduce scope to vault-only if needed |
| intelagent complexity underestimated | High | High | Defer to Phase 4 (Scenario B) |
| Integration testing takes longer | Medium | Low | Automated test harness from Phase 0 |

---

## References

### Related Documents
- `STATUS.md` - Current project status
- `NEXT_STEPS.md` - Phase 1 detailed roadmap
- `INTEGRATION.md` - Integration guide for services
- `README.md` - Architecture overview

### External Resources
- [NATS JetStream Architecture](https://docs.nats.io/nats-concepts/jetstream)
- [Architecture Decision Records (ADRs)](https://adr.github.io/)
- [Event-Driven Architecture Patterns](https://martinfowler.com/articles/201701-event-driven.html)

---

**Document Status**: Draft for Architect Review
**Next Action**: Review ADRs, select Phase 1 integration strategy
**Approval Required**: Phase 1 project selection (ADR-001), Integration pattern (ADR-002)

---

## ADR-0039: Service Mesh Adoption — Linkerd over Istio/Cilium

**Status**: Accepted
**Date**: 2026-02-17
**Classification**: Major
**Project**: SPECTRE (spectre-proxy)
**Issue**: #45 Service Mesh Evaluation

---

### Context

SPECTRE operates under a zero-trust network model where east-west traffic between services
(spectre-proxy → neutron, spectre-proxy → NATS) must be encrypted and mutually authenticated.
Phase 3 validation exposed three concrete requirements:

1. **mTLS** between all service-to-service calls — prevent MITM on cluster networks
2. **L7 observability** — per-route latency/error-rate without code changes to spectre-proxy
3. **Traffic policies** — timeouts and retry budgets per endpoint (e.g. `/ingest` vs `/health`)

A service mesh was chosen over application-level TLS because:
- Application TLS requires managing certificates in every service (cognitive-vault, neutron, proxy)
- L7 metrics would need per-service Prometheus instrumentation
- Retry/timeout logic is already implemented in spectre-proxy but a mesh makes it auditable externally

---

### Decision

**Linkerd stable-2.14.x** was selected as the service mesh for SPECTRE.

Linkerd is deployed on the kind cluster (`spectre-dev`) with:
- Automatic sidecar injection for `spectre-proxy` (2/2 containers confirmed)
- Stub neutron (`ghcr.io/mccutchen/go-httpbin:v2.14.0`) injected for mTLS validation
- ServiceProfile CRD defining per-route policies for spectre-proxy
- NATS outbound ports (4222) excluded from proxy interception to avoid protocol misdetection

---

### Alternatives Considered

#### Alternative 1: Istio (Rejected)

**Pros**:
- ✅ Feature-rich: traffic splitting, fault injection, Wasm filters
- ✅ Large community, extensive documentation
- ✅ Native Kubernetes Gateway API support

**Cons**:
- ❌ Heavy control plane: ~300MB memory (istiod + proxies) vs ~15MB for Linkerd
- ❌ Complex CRD surface: VirtualService, DestinationRule, Gateway, PeerAuthentication (25+ CRDs)
- ❌ Envoy proxy per sidecar: larger attack surface, harder to audit
- ❌ SPIFFE/SPIRE cert rotation has had CVEs (CVE-2022-24752)

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 6/10 | Envoy overhead ~2-5ms p99 |
| Maintainability | 5/10 | CRD sprawl, complex upgrades |
| Complexity | 3/10 | 25+ CRDs to understand |
| Resource Usage | 4/10 | ~300MB control plane |
| Security | 7/10 | Mature but large attack surface |

**Overall**: 5/10 — Eliminated; SPECTRE does not need traffic splitting or Wasm.

---

#### Alternative 2: Cilium Service Mesh (Rejected)

**Pros**:
- ✅ eBPF-based: kernel-level enforcement, no sidecar overhead
- ✅ Network policy + mesh in one agent
- ✅ Excellent performance: near-zero latency overhead

**Cons**:
- ❌ Requires Linux kernel ≥ 5.10 (kind nodes run 5.15+ but production constraint)
- ❌ eBPF maps need `CAP_BPF` / `CAP_NET_ADMIN` — restricted in hardened clusters
- ❌ Mutual TLS via WireGuard (node-level, not pod-level) — cannot enforce per-pod identity
- ❌ L7 policies require Hubble which adds ~100MB overhead
- ❌ kind cluster eBPF support requires privileged containers (security regression)

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 10/10 | eBPF near-zero overhead |
| Maintainability | 7/10 | Single agent, unified network+mesh |
| Complexity | 5/10 | eBPF debugging requires kernel expertise |
| Resource Usage | 8/10 | No sidecars, one DaemonSet |
| Security | 6/10 | Node-level mTLS, not pod-level identity |

**Overall**: 7/10 — Strong candidate for Phase 5 when running on bare-metal NixOS nodes.
Deferred: kind environment and current kernel constraints make it premature.

---

#### Alternative 3: Linkerd (Selected) ✅

**Pros**:
- ✅ Lightweight: ~15MB Rust proxy (linkerd2-proxy) per sidecar
- ✅ Zero-config mTLS: automatic SPIFFE certificate rotation via linkerd-identity
- ✅ Simple mental model: ~5 CRDs total (ServiceProfile, Server, HTTPRoute, etc.)
- ✅ Rust-based data plane — shares safety properties with spectre-proxy's Rust codebase
- ✅ ServiceProfile CRD: per-route timeout + retry budget without application changes
- ✅ `linkerd viz` golden metrics (success rate, RPS, p50/p95/p99) per deployment

**Cons**:
- ❌ No traffic splitting without SMI adaptor (not needed for SPECTRE currently)
- ❌ UDP not proxied (NATS uses TCP so this is irrelevant)
- ❌ Smaller community than Istio

**Trade-Offs**:
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance | 9/10 | Rust proxy +~0.5ms p50, <2ms p99 |
| Maintainability | 9/10 | Minimal CRDs, clean upgrade path |
| Complexity | 9/10 | linkerd install + inject annotation |
| Resource Usage | 9/10 | ~15MB sidecar, ~50MB control plane |
| Security | 9/10 | SPIFFE identity, automatic mTLS, RBAC |

**Overall**: 9/10 — Best fit for SPECTRE's current requirements.

---

### Recommendation Matrix

| Mesh | Performance | Maintainability | Complexity | Resources | Security | Overall |
|------|-------------|-----------------|------------|-----------|----------|---------|
| Istio | 6/10 | 5/10 | 3/10 | 4/10 | 7/10 | 5.0/10 |
| Cilium | 10/10 | 7/10 | 5/10 | 8/10 | 6/10 | 7.2/10 |
| **Linkerd** | **9/10** | **9/10** | **9/10** | **9/10** | **9/10** | **9.0/10** ✅ |

---

### Consequences

#### Positive
- mTLS is automatic for all meshed pods — no application code changes required
- `linkerd viz tap` provides real-time L7 request inspection for debugging
- ServiceProfile enables per-route SLO enforcement (timeouts, retries) externally from app code
- Benchmark shows **+~0.5ms p50 / +~1.5ms p99** overhead (acceptable for async workloads)
- Zero-trust posture achieved: all spectre-proxy ↔ neutron traffic encrypted + authenticated

#### Negative / Trade-offs
- Each meshed pod uses ~15MB additional RAM (linkerd2-proxy sidecar)
- NATS port 4222 must be excluded from interception (`skip-outbound-ports: 4222`) because
  Linkerd cannot proxy the NATS binary protocol
- Linkerd does not proxy UDP — irrelevant now but limits future UDP-based protocols

#### Migration Path
- **Phase 4**: Deploy production neutron behind Linkerd mesh for real mTLS validation
- **Phase 5**: Evaluate Cilium as replacement if eBPF kernel constraints are met on bare metal

---

### Validation

| Check | Command | Expected Result |
|-------|---------|-----------------|
| mTLS active | `linkerd viz edges deployment` | TLS column = true for spectre-proxy ↔ neutron |
| Traffic visible | `linkerd viz tap deployment/spectre-proxy --to deployment/neutron` | Requests visible with mTLS |
| Routes active | `linkerd viz routes deployment/spectre-proxy` | POST /ingest and GET /health listed |
| Overhead | wrk2 with vs without sidecar | p50 delta ≤ 1ms, p99 delta ≤ 2ms |

---

### References

- [Linkerd stable-2.14 docs](https://linkerd.io/2.14/overview/)
- [Linkerd ServiceProfile spec](https://linkerd.io/2.14/reference/service-profiles/)
- [Linkerd vs Istio benchmark (2024)](https://linkerd.io/2021/11/29/linkerd-vs-istio-benchmarks-2021/)
- SPECTRE #45: Service Mesh Evaluation
- `nix/kubernetes/neutron-stub.nix` — stub neutron Deployment + Service
- `nix/kubernetes/service-profile.nix` — ServiceProfile CRD for spectre-proxy

---

## ADR-0040: Phase 3→4 Transition — Stub Neutron to Production Backend

**Status**: Accepted
**Date**: 2026-02-17
**Classification**: Major
**Project**: SPECTRE (spectre-proxy, neutron/NEXUS)
**Supersedes**: —
**Related**: ADR-0039 (Service Mesh Adoption)

---

### Context

Phase 3 validated the service mesh infrastructure using a **stub neutron** — a stateless HTTP
echo server (`ghcr.io/mccutchen/go-httpbin:v2.14.0`) deployed under the same Kubernetes service
name (`neutron.default.svc.cluster.local:8000`) that the real backend will use.

This stub was sufficient to prove:
- mTLS between spectre-proxy ↔ neutron (SECURED = ✓ via `linkerd viz edges`)
- Linkerd sidecar injection on both ends (2/2 containers)
- ServiceProfile route classification (POST /ingest, GET /health)
- Golden metrics collection (success rate, RPS, p50/p95/p99)

However, the stub does **not** exercise:
- Actual inference latency (CUDA, model loading, GPU scheduling)
- NATS event flow end-to-end (proxy → NATS → neutron → response)
- Circuit breaker under real failure modes (OOM, GPU exhaustion, model timeout)
- Trace propagation across the full proxy → neutron path (W3C traceparent)
- Realistic payload sizes (LLM request/response bodies: 1KB–100KB)

Phase 4 requires replacing the stub with a production-capable neutron backend.

---

### Decision

Adopt a **graduated replacement strategy** with three stages, each independently
deployable and validated before proceeding to the next.

---

#### Stage 1: Lightweight Neutron Shim (Phase 4 entry)

**Image**: Custom minimal container (Python/FastAPI or Rust/Axum)
**Scope**: HTTP API contract + NATS consumer — no CUDA, no real inference

```
spectre-proxy → neutron-shim (HTTP :8000)
                     ├── POST /ingest → fake inference (random latency 50-500ms)
                     ├── GET /health → 200
                     └── NATS subscriber: spectre.ingest.v1 → ack
```

**What it validates**:
- Full NATS round-trip (proxy publishes → neutron consumes → response)
- Realistic HTTP response structure (JSON with model output fields)
- Circuit breaker under simulated failures (shim returns 500 at configurable rate)
- Trace propagation: spectre-proxy span → neutron-shim span in Jaeger
- Mesh overhead under sustained load (wrk2 benchmark with real payload)

**Nix integration**:
- `nix/kubernetes/neutron-shim.nix` replaces `neutron-stub.nix`
- Same Service name, same port — zero changes to spectre-proxy config
- Linkerd injection annotation preserved

**Exit criteria**:
- [ ] NATS publish → consume → response latency < 50ms p99
- [ ] Circuit breaker trips at 50% error rate, recovers after 30s
- [ ] Trace spans visible in Jaeger: `spectre-proxy` → `neutron-shim`
- [ ] wrk2 benchmark: ≥ 10K RPS on /ingest with mesh (p99 < 20ms)

---

#### Stage 2: NEXUS Lite (Phase 4 mid)

**Image**: Stripped NEXUS build — Python + FastAPI + Ray Serve, **no CUDA**
**Scope**: Real inference API with CPU-only models (e.g., distilbert, small LLMs via llama.cpp CPU)

```
spectre-proxy → neutron-lite (HTTP :8000)
                     ├── POST /ingest → real inference (CPU model, 200ms-2s)
                     ├── GET /health → 200 + model status
                     ├── GET /metrics → Prometheus (inference_latency, queue_depth)
                     └── NATS: spectre.ingest.v1 → inference → spectre.result.v1
```

**What it validates**:
- Real inference latency profiles under mesh (not fake random)
- Memory pressure from model loading (1-4GB for CPU models)
- Ray Serve autoscaling interaction with Linkerd load balancing
- Request queuing behavior (burst → queue → timeout → circuit break)
- pgvector integration for RAG context retrieval (if applicable)

**Image build strategy**:
- Multi-stage Dockerfile: Python deps in layer 1, model weights volume-mounted
- No CUDA toolkit → image < 2GB (vs 8-12GB for full NEXUS)
- Nix: `nix build .#neutron-lite-image` using `pkgs.dockerTools.buildLayeredImage`

**Exit criteria**:
- [ ] Inference round-trip (proxy → NATS → neutron → response) < 3s p99
- [ ] Model hot-reload without pod restart
- [ ] Memory stays < 4GB under sustained load
- [ ] Mesh overhead negligible vs inference latency (< 5% of total p99)

---

#### Stage 3: Full NEXUS (Phase 4 exit / Phase 5 entry)

**Image**: Full NEXUS with CUDA, Ray, pgvector
**Scope**: Production deployment — GPU inference, vector search, multi-model routing

```
spectre-proxy → neutron (HTTP :8000)
                     ├── POST /ingest → GPU inference (50ms-5s depending on model)
                     ├── POST /embed → vector embedding
                     ├── GET /health → 200 + GPU/VRAM status
                     ├── GET /metrics → inference_latency, vram_usage, queue_depth
                     └── NATS: full event schema (ingest, result, error, cost)
```

**Prerequisites**:
- Bare-metal or GPU-enabled nodes (NVIDIA runtime, device plugin)
- Persistent volume for model weights (50-200GB)
- NATS JetStream for durable delivery (exactly-once on inference requests)

**What changes from mesh perspective**:
- ServiceProfile updated: POST /ingest timeout 10s → 30s (GPU inference slower)
- RetryBudget reduced: 20% → 5% (inference is expensive, don't retry aggressively)
- Linkerd load balancing: EWMA for latency-aware routing across GPU replicas

**Exit criteria**:
- [ ] GPU inference < 5s p99 through mesh
- [ ] VRAM-aware routing via custom metrics (HPA + Prometheus adapter)
- [ ] mTLS maintained with zero application changes from Stage 1
- [ ] ServiceProfile routes updated for new endpoints (/embed, /models)

---

### Alternatives Considered

#### Alt 1: Skip Directly to Full NEXUS (Rejected)

Build and deploy the complete NEXUS image immediately.

**Pros**: No intermediate steps, production-ready sooner
**Cons**:
- ❌ CUDA image is 8-12GB — slow build, slow kind load
- ❌ Requires GPU node (not available in kind cluster)
- ❌ Debugging mesh issues mixed with GPU/CUDA issues
- ❌ Blocks Phase 4 progress until GPU infrastructure ready

**Verdict**: Rejected. Coupling infrastructure validation with GPU complexity adds risk.

#### Alt 2: Keep Stub Forever, Test Real Backend Outside Mesh (Rejected)

Keep go-httpbin as stub, validate NEXUS separately without mesh.

**Pros**: Simple, no new containers to build
**Cons**:
- ❌ Never validates NATS end-to-end through mesh
- ❌ Mesh overhead under real payloads unknown until production
- ❌ Circuit breaker behavior with real failure modes untested

**Verdict**: Rejected. Defeats the purpose of Phase 3→4 graduation.

#### Alt 3: Graduated Replacement (Selected) ✅

Three stages: shim → lite → full (this ADR).

**Pros**:
- ✅ Each stage independently deployable and testable
- ✅ Zero changes to spectre-proxy between stages (same Service name/port)
- ✅ Mesh infrastructure validated incrementally under increasing realism
- ✅ Can run in kind (stages 1-2) or bare metal (stage 3)

**Verdict**: Selected. De-risks transition, validates mesh under progressively realistic conditions.

---

### Consequences

#### Positive
- spectre-proxy is **completely decoupled** from the neutron backend implementation —
  any container exposing HTTP :8000 with the `neutron` Service name works
- Each stage produces measurable validation data (latency, throughput, failure modes)
  before committing to the next
- Stub → shim → lite → full path means Phase 4 can start immediately without GPU hardware
- Mesh configuration (ServiceProfile, mTLS, viz) is validated once and carried forward

#### Negative / Trade-offs
- Three container images to maintain during transition (stub, shim, lite)
- ServiceProfile timeouts must be updated per stage (10s → 30s for GPU)
- Stage 2 CPU inference is not representative of GPU latency — benchmarks are
  directional, not production baselines

#### What Stays the Same Across All Stages
| Component | Value |
|-----------|-------|
| Service name | `neutron.default.svc.cluster.local` |
| Service port | `8000` |
| Linkerd injection | `linkerd.io/inject: enabled` |
| mTLS | Automatic (SPIFFE identity) |
| spectre-proxy config | `NEUTRON_URL=http://neutron.default.svc.cluster.local:8000` |
| Nix package | `nix build .#neutron-{stub,shim,lite}-manifests` |

---

### Timeline

| Stage | Target | Blockers |
|-------|--------|----------|
| Stage 1 (Shim) | Phase 4 start (Mar 2026) | None — can start now |
| Stage 2 (Lite) | Phase 4 mid (Apr 2026) | NEXUS Python deps in Nix |
| Stage 3 (Full) | Phase 4 exit (Jun 2026) | GPU nodes, NVIDIA runtime |

---

### References

- ADR-0039: Service Mesh Adoption (Linkerd)
- SPECTRE ROADMAP.md: Phase 4 Enterprise Features
- `nix/kubernetes/neutron-stub.nix` — current Stage 0 (go-httpbin)
- `nix/kubernetes/default.nix` — Kubernetes manifest composition
- NEXUS/neutron: `~/dev/low-level/neutron/` (external repo)
