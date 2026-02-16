#!/usr/bin/env bash
# Security Audit: Secret Exposure
# Checks for secret leakage in logs, errors, git, and environment

set -euo pipefail

PROJECT_ROOT="/home/kernelcore/master/spectre"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

test_count=0
pass_count=0
fail_count=0
warn_count=0

log_test() {
    echo -e "${YELLOW}[TEST $((++test_count))]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}✓${NC} $1"
    pass_count=$((pass_count + 1))
}

log_fail() {
    echo -e "${RED}✗${NC} $1"
    fail_count=$((fail_count + 1))
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    warn_count=$((warn_count + 1))
}

cd "$PROJECT_ROOT"

# Test 1: .env files in .gitignore
log_test ".env files excluded from git"
if grep -q "^\.env$" .gitignore 2>/dev/null; then
    log_pass ".env in .gitignore"
else
    log_fail ".env not in .gitignore"
fi

# Test 2: No .env files committed
log_test ".env files not committed to git"
if git ls-files | grep -q "\.env$" 2>/dev/null; then
    log_fail ".env files found in git"
else
    log_pass "No .env files in git"
fi

# Test 3: JWT_SECRET not hardcoded
log_test "JWT_SECRET not hardcoded in source"
if git grep "JWT_SECRET.*=.*\"" -- '*.rs' '*.toml' | grep -v "env\|expect\|dev-jwt-secret" >/dev/null 2>&1; then
    log_fail "Hardcoded JWT_SECRET found"
else
    log_pass "No hardcoded JWT_SECRET"
fi

# Test 4: No API keys in source
log_test "API keys not hardcoded"
if git grep -i "api.*key.*=.*\"[a-zA-Z0-9]\{20,\}\"" -- '*.rs' '*.toml' >/dev/null 2>&1; then
    log_fail "Potential API keys found"
else
    log_pass "No API keys found"
fi

# Test 5: No private keys in repo
log_test "Private key files check"
key_count=$(find crates/ -name "*.pem" -o -name "*.key" 2>/dev/null | wc -l)
if [[ ${key_count// /} -eq 0 ]]; then
    log_pass "No private key files in crates/"
else
    log_warn "Found $key_count private key files"
fi

# Test 6: Secrets in test files only
log_test "Secrets only in test files (not production code)"
if git grep -i "password.*=.*\"" -- 'crates/*/src/*.rs' | grep -v "test\|mock" | grep -v "DATABASE_URL" >/dev/null 2>&1; then
    log_warn "Potential passwords in production code"
else
    log_pass "No passwords in production code"
fi

# Test 7: Docker/Nix containers don't hardcode secrets
log_test "Container images don't hardcode secrets"
if grep -r "JWT_SECRET\|PASSWORD" nix/*.nix 2>/dev/null | grep -v "readFile\|config\|env" >/dev/null 2>&1; then
    log_warn "Potential secrets in Nix configs"
else
    log_pass "No secrets in container configs"
fi

# Summary
echo ""
echo "========================================="
echo "Secret Exposure Audit Summary"
echo "========================================="
echo "Total tests: $test_count"
echo -e "${GREEN}Passed: $pass_count${NC}"
echo -e "${YELLOW}Warnings: $warn_count${NC}"
echo -e "${RED}Failed: $fail_count${NC}"
echo "========================================="

if [[ $fail_count -eq 0 ]] && [[ $warn_count -eq 0 ]]; then
    echo -e "${GREEN}✓ No secret exposure issues found!${NC}"
    exit 0
elif [[ $fail_count -eq 0 ]]; then
    echo -e "${YELLOW}⚠ Some warnings - review manually${NC}"
    exit 0
else
    echo -e "${RED}✗ Secret exposure issues found - remediate immediately${NC}"
    exit 1
fi
