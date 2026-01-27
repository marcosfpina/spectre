#!/usr/bin/env bash
#
# SPECTRE Fleet - Test Runner
# Executes all tests in sequence with proper setup and teardown
#

set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail # Exit if any command in a pipe fails

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if running in Nix shell
    if [ -z "${IN_NIX_SHELL:-}" ]; then
        log_warning "Not in Nix shell. Entering nix develop..."
        exec nix develop --command "$0" "$@"
    fi

    # Check if docker-compose is available
    if ! command -v docker-compose &> /dev/null; then
        log_error "docker-compose not found. Please install it."
        exit 1
    fi

    # Check if cargo is available
    if ! command -v cargo &> /dev/null; then
        log_error "cargo not found. Please ensure Rust is installed."
        exit 1
    fi

    log_success "Prerequisites OK"
}

# Start infrastructure
start_infrastructure() {
    log_info "Starting infrastructure (NATS, TimescaleDB, Neo4j)..."

    # Check if already running
    if docker-compose ps | grep -q "Up"; then
        log_warning "Infrastructure already running"
        return 0
    fi

    docker-compose up -d

    # Wait for NATS
    log_info "Waiting for NATS to be ready..."
    for i in {1..30}; do
        if docker-compose exec -T nats wget -q --spider http://localhost:8222/healthz &>/dev/null; then
            log_success "NATS is ready"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "NATS failed to start"
            return 1
        fi
        sleep 1
    done

    # Wait for TimescaleDB
    log_info "Waiting for TimescaleDB to be ready..."
    for i in {1..30}; do
        if docker-compose exec -T timescaledb pg_isready -U spectre &>/dev/null; then
            log_success "TimescaleDB is ready"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "TimescaleDB failed to start"
            return 1
        fi
        sleep 1
    done

    # Wait for Neo4j
    log_info "Waiting for Neo4j to be ready..."
    for i in {1..30}; do
        if docker-compose exec -T neo4j cypher-shell -u neo4j -p spectre_dev_password "RETURN 1" &>/dev/null; then
            log_success "Neo4j is ready"
            break
        fi
        if [ $i -eq 30 ]; then
            log_warning "Neo4j may not be ready (non-critical)"
            break
        fi
        sleep 1
    done

    log_success "Infrastructure started"
}

# Stop infrastructure
stop_infrastructure() {
    if [ "${KEEP_INFRA:-0}" -eq 1 ]; then
        log_warning "Keeping infrastructure running (KEEP_INFRA=1)"
        return 0
    fi

    log_info "Stopping infrastructure..."
    docker-compose down
    log_success "Infrastructure stopped"
}

# Run unit tests
run_unit_tests() {
    log_info "═══════════════════════════════════════"
    log_info "  PHASE 1: Unit Tests"
    log_info "═══════════════════════════════════════"

    local tests=(
        "spectre-core"
        "spectre-events"
    )

    for crate in "${tests[@]}"; do
        log_info "Running unit tests for ${crate}..."
        TOTAL_TESTS=$((TOTAL_TESTS + 1))

        if cargo test -p "${crate}" --lib -- --nocapture 2>&1 | tee "/tmp/spectre-test-${crate}.log"; then
            log_success "✅ ${crate} unit tests passed"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            log_error "❌ ${crate} unit tests failed"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    done
}

# Run integration tests
run_integration_tests() {
    log_info "═══════════════════════════════════════"
    log_info "  PHASE 2: Integration Tests"
    log_info "═══════════════════════════════════════"

    log_info "Running integration tests..."
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if cargo test --tests -- --test-threads=1 --nocapture 2>&1 | tee /tmp/spectre-test-integration.log; then
        log_success "✅ Integration tests passed"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log_error "❌ Integration tests failed"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Run clippy (linting)
run_clippy() {
    log_info "═══════════════════════════════════════"
    log_info "  PHASE 3: Clippy (Linting)"
    log_info "═══════════════════════════════════════"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if cargo clippy --all-targets --all-features -- -D warnings 2>&1 | tee /tmp/spectre-clippy.log; then
        log_success "✅ Clippy passed"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log_error "❌ Clippy found issues"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Run formatting check
run_fmt_check() {
    log_info "═══════════════════════════════════════"
    log_info "  PHASE 4: Format Check"
    log_info "═══════════════════════════════════════"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if cargo fmt -- --check 2>&1 | tee /tmp/spectre-fmt.log; then
        log_success "✅ Format check passed"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log_error "❌ Format check failed (run: cargo fmt)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Run benchmarks (optional)
run_benchmarks() {
    if [ "${RUN_BENCHMARKS:-0}" -ne 1 ]; then
        log_warning "Skipping benchmarks (set RUN_BENCHMARKS=1 to run)"
        return 0
    fi

    log_info "═══════════════════════════════════════"
    log_info "  PHASE 5: Benchmarks"
    log_info "═══════════════════════════════════════"

    log_info "Running benchmarks..."
    # cargo bench 2>&1 | tee /tmp/spectre-bench.log
    log_warning "Benchmarks not yet implemented"
}

# Print summary
print_summary() {
    log_info "═══════════════════════════════════════"
    log_info "  TEST SUMMARY"
    log_info "═══════════════════════════════════════"

    echo ""
    echo "Total Tests:   ${TOTAL_TESTS}"
    echo -e "${GREEN}Passed:${NC}        ${PASSED_TESTS}"
    echo -e "${RED}Failed:${NC}        ${FAILED_TESTS}"
    echo -e "${YELLOW}Skipped:${NC}       ${SKIPPED_TESTS}"
    echo ""

    if [ ${FAILED_TESTS} -eq 0 ]; then
        log_success "🎉 All tests passed!"
        return 0
    else
        log_error "❌ Some tests failed"
        return 1
    fi
}

# Main execution
main() {
    local start_time=$(date +%s)

    echo ""
    log_info "═══════════════════════════════════════"
    log_info "  SPECTRE Fleet Test Suite"
    log_info "═══════════════════════════════════════"
    echo ""

    check_prerequisites
    start_infrastructure

    # Run test phases
    run_unit_tests
    run_integration_tests
    run_clippy
    run_fmt_check
    run_benchmarks

    # Cleanup
    stop_infrastructure

    # Summary
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    log_info "Test suite completed in ${duration}s"
    print_summary

    # Exit with appropriate code
    if [ ${FAILED_TESTS} -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Trap cleanup on exit
trap 'stop_infrastructure' EXIT INT TERM

# Run main if executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
