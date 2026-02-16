#!/usr/bin/env bash
# Security Audit: JWT Edge Cases
# Tests JWT validation edge cases for spectre-proxy

set -euo pipefail

PROXY_URL="${PROXY_URL:-http://localhost:3000}"
JWT_SECRET="${JWT_SECRET:-dev-jwt-secret-spectre-2026}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

test_count=0
pass_count=0
fail_count=0

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

# JWT generation (pure bash, base64url encoding)
base64url_encode() {
    openssl base64 -A | tr '+/' '-_' | tr -d '='
}

generate_jwt() {
    local payload="$1"
    local secret="$2"

    # Header (HS256)
    local header='{"alg":"HS256","typ":"JWT"}'
    local header_b64=$(echo -n "$header" | base64url_encode)
    local payload_b64=$(echo -n "$payload" | base64url_encode)

    # Signature
    local signature=$(echo -n "${header_b64}.${payload_b64}" | \
        openssl dgst -sha256 -hmac "$secret" -binary | base64url_encode)

    echo "${header_b64}.${payload_b64}.${signature}"
}

# Test 1: Valid token
log_test "Valid JWT token"
now=$(date +%s)
exp=$((now + 3600))
payload="{\"sub\":\"user123\",\"role\":\"service\",\"exp\":$exp,\"iat\":$now}"
token=$(generate_jwt "$payload" "$JWT_SECRET")
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$PROXY_URL/api/v1/ingest" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d '{"event_type":"test","payload":{}}')
if [[ "$response" == "200" ]] || [[ "$response" == "429" ]]; then
    log_pass "Valid token accepted (HTTP $response)"
else
    log_fail "Valid token rejected (HTTP $response, expected 200/429)"
fi

# Test 2: Expired token
log_test "Expired JWT token"
exp=$((now - 3600))  # Expired 1 hour ago
payload="{\"sub\":\"user123\",\"role\":\"service\",\"exp\":$exp,\"iat\":$((now - 7200))}"
token=$(generate_jwt "$payload" "$JWT_SECRET")
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$PROXY_URL/api/v1/ingest" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d '{"event_type":"test","payload":{}}')
if [[ "$response" == "401" ]]; then
    log_pass "Expired token rejected (HTTP 401)"
else
    log_fail "Expired token not rejected (HTTP $response, expected 401)"
fi

# Test 3: Invalid signature
log_test "Invalid signature"
payload="{\"sub\":\"user123\",\"role\":\"admin\",\"exp\":$exp,\"iat\":$now}"
token=$(generate_jwt "$payload" "wrong-secret-key")
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$PROXY_URL/api/v1/ingest" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d '{"event_type":"test","payload":{}}')
if [[ "$response" == "401" ]]; then
    log_pass "Invalid signature rejected (HTTP 401)"
else
    log_fail "Invalid signature not rejected (HTTP $response, expected 401)"
fi

# Test 4: Missing 'sub' claim
log_test "Missing 'sub' claim"
exp=$((now + 3600))
payload="{\"role\":\"service\",\"exp\":$exp,\"iat\":$now}"
token=$(generate_jwt "$payload" "$JWT_SECRET")
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$PROXY_URL/api/v1/ingest" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d '{"event_type":"test","payload":{}}')
if [[ "$response" == "401" ]]; then
    log_pass "Missing 'sub' claim rejected (HTTP 401)"
else
    log_fail "Missing 'sub' claim not rejected (HTTP $response, expected 401)"
fi

# Test 5: Missing 'role' claim
log_test "Missing 'role' claim"
payload="{\"sub\":\"user123\",\"exp\":$exp,\"iat\":$now}"
token=$(generate_jwt "$payload" "$JWT_SECRET")
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$PROXY_URL/api/v1/ingest" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d '{"event_type":"test","payload":{}}')
if [[ "$response" == "401" ]]; then
    log_pass "Missing 'role' claim rejected (HTTP 401)"
else
    log_fail "Missing 'role' claim not rejected (HTTP $response, expected 401)"
fi

# Test 6: Algorithm confusion (none algorithm)
log_test "Algorithm confusion attack (none)"
payload="{\"sub\":\"user123\",\"role\":\"admin\",\"exp\":$exp,\"iat\":$now}"
header='{"alg":"none","typ":"JWT"}'
header_b64=$(echo -n "$header" | base64url_encode)
payload_b64=$(echo -n "$payload" | base64url_encode)
token="${header_b64}.${payload_b64}."  # No signature for 'none' alg
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$PROXY_URL/api/v1/ingest" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d '{"event_type":"test","payload":{}}')
if [[ "$response" == "401" ]]; then
    log_pass "Algorithm 'none' rejected (HTTP 401)"
else
    log_fail "Algorithm 'none' accepted! CRITICAL VULNERABILITY (HTTP $response)"
fi

# Test 7: Malformed token (only 2 parts)
log_test "Malformed JWT (only 2 parts)"
token="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyMTIzIn0"
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$PROXY_URL/api/v1/ingest" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d '{"event_type":"test","payload":{}}')
if [[ "$response" == "401" ]]; then
    log_pass "Malformed token rejected (HTTP 401)"
else
    log_fail "Malformed token not rejected (HTTP $response, expected 401)"
fi

# Test 8: Empty token
log_test "Empty JWT token"
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$PROXY_URL/api/v1/ingest" \
    -H "Authorization: Bearer " \
    -H "Content-Type: application/json" \
    -d '{"event_type":"test","payload":{}}')
if [[ "$response" == "401" ]]; then
    log_pass "Empty token rejected (HTTP 401)"
else
    log_fail "Empty token not rejected (HTTP $response, expected 401)"
fi

# Test 9: Missing Authorization header
log_test "Missing Authorization header"
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$PROXY_URL/api/v1/ingest" \
    -H "Content-Type: application/json" \
    -d '{"event_type":"test","payload":{}}')
if [[ "$response" == "401" ]]; then
    log_pass "Missing auth header rejected (HTTP 401)"
else
    log_fail "Missing auth header not rejected (HTTP $response, expected 401)"
fi

# Summary
echo ""
echo "========================================="
echo "JWT Security Test Summary"
echo "========================================="
echo "Total tests: $test_count"
echo -e "${GREEN}Passed: $pass_count${NC}"
echo -e "${RED}Failed: $fail_count${NC}"
echo "========================================="

if [[ $fail_count -eq 0 ]]; then
    echo -e "${GREEN}✓ All JWT security tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some JWT tests failed - review security implementation${NC}"
    exit 1
fi
