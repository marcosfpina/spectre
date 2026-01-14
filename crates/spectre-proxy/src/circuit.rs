use std::sync::{
    atomic::{AtomicUsize, Ordering},
    RwLock,
};
use std::time::{Duration, Instant};

/// Circuit Breaker States
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CircuitState {
    Closed,   // Normal operation
    Open,     // Failing, reject requests
    HalfOpen, // Testing if service recovered
}

/// Circuit Breaker Configuration
#[derive(Debug, Clone)]
pub struct CircuitConfig {
    pub failure_threshold: usize,
    pub reset_timeout: Duration,
}

impl Default for CircuitConfig {
    fn default() -> Self {
        Self {
            failure_threshold: 5,
            reset_timeout: Duration::from_secs(30),
        }
    }
}

/// Circuit Breaker implementation
#[derive(Debug)]
pub struct CircuitBreaker {
    state: RwLock<CircuitState>,
    failure_count: AtomicUsize,
    last_failure: RwLock<Option<Instant>>,
    config: CircuitConfig,
}

impl CircuitBreaker {
    pub fn new(config: CircuitConfig) -> Self {
        Self {
            state: RwLock::new(CircuitState::Closed),
            failure_count: AtomicUsize::new(0),
            last_failure: RwLock::new(None),
            config,
        }
    }

    /// Check if request should proceed
    pub fn allow_request(&self) -> bool {
        let state = *self.state.read().unwrap();
        match state {
            CircuitState::Closed => true,
            CircuitState::Open => {
                // Check if timeout passed to switch to HalfOpen
                let last_fail = *self.last_failure.read().unwrap();
                if let Some(time) = last_fail {
                    if time.elapsed() >= self.config.reset_timeout {
                        // Attempt to switch to HalfOpen
                        if let Ok(mut write_state) = self.state.write() {
                            *write_state = CircuitState::HalfOpen;
                            return true; // Allow one probe request
                        }
                    }
                }
                false
            }
            CircuitState::HalfOpen => {
                // In a real implementation, we might limit concurrent half-open requests.
                // For simplicity, we assume the caller handles serialization or we allow bursts.
                true
            }
        }
    }

    /// Report a successful request
    pub fn record_success(&self) {
        let state = *self.state.read().unwrap();
        if state == CircuitState::HalfOpen {
            // Service recovered
            if let Ok(mut write_state) = self.state.write() {
                *write_state = CircuitState::Closed;
                self.failure_count.store(0, Ordering::Relaxed);
                *self.last_failure.write().unwrap() = None;
            }
        } else {
            // Normal success, reset failures just in case
            self.failure_count.store(0, Ordering::Relaxed);
        }
    }

    /// Report a failed request
    pub fn record_failure(&self) {
        let failures = self.failure_count.fetch_add(1, Ordering::Relaxed) + 1;
        *self.last_failure.write().unwrap() = Some(Instant::now());

        if failures >= self.config.failure_threshold {
            if let Ok(mut write_state) = self.state.write() {
                *write_state = CircuitState::Open;
            }
        }
    }
}
