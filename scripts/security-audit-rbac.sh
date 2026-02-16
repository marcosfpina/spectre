#!/usr/bin/env bash
# Security Audit: RBAC Bypass Attempts
# Tests role-based access control enforcement

set -euo pipefail

PROXY_URL="${PROXY_URL:-http://localhost:3000}"
JWT_SECRET="${JWT_SECRET:-dev-jwt-secret-spectre-2026}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# JWT generation
base64url_encode() {
    openssl base64 -A | tr '+/' '-_' | tr -d '='
}

generate_jwt() {
    local payload="$1"
    local secret="$2"
    local header='{"alg":"HS256","typ":"JWT"}'
    local header_b64=$(echo -n "$header" | base64url_encode)
    local payload_b64=$(echo -n "$payload" | base64url_encode)
    local signature=$(echo -n "${header_b64}.${payload_b64}" | \
        openssl dgst -sha256 -hmac "$secret" -binary | base64url_encode)
    echo "${header_b64}.${payload_b64}.${signature}"
}

now=$(date +%s)
exp=$((now + 3600))

# Test 1: Readonly accessing service endpoint
log_test "Readonly role accessing /api/v1/ingest (requires service)"
payload="{\"sub\":\"readonly_user\",\"role\":\"readonly\",\"exp\":$exp,\"iat\":$now}"
token=$(generate_jwt "$payload" "$JWT_SECRET")
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$PROXY_URL/api/v1/ingest" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d '{"event_type":"test","payload":{}}')
if [[ "$response" == "403" ]]; then
    log_pass "Readonly role denied service endpoint (HTTP 403)"
else
    log_fail "RBAC bypass! Readonly accessed service endpoint (HTTP $response, expected 403)"
fi

# Test 2: Service accessing admin endpoint
log_test "Service role accessing /api/v1/admin/* (requires admin)"
payload="{\"sub\":\"service_user\",\"role\":\"service\",\"exp\":$exp,\"iat\":$now}"
token=$(generate_jwt "$payload" "$JWT_SECRET")
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$PROXY_URL/api/v1/admin/config" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d '{}')
if [[ "$response" == "403" ]] || [[ "$response" == "404" ]]; then
    log_pass "Service role denied admin endpoint (HTTP $response)"
else
    log_fail "RBAC bypass! Service accessed admin endpoint (HTTP $response, expected 403/404)"
fi

# Test 3: Admin can access service endpoints
log_test "Admin role accessing /api/v1/ingest (admin > service)"
payload="{\"sub\":\"admin_user\",\"role\":\"admin\",\"exp\":$exp,\"iat\":$now}"
token=$(generate_jwt "$payload" "$JWT_SECRET")
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$PROXY_URL/api/v1/ingest" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d '{"event_type":"test","payload":{}}')
if [[ "$response" == "200" ]] || [[ "$response" == "429" ]]; then
    log_pass "Admin role can access service endpoint (HTTP $response)"
else
    log_fail "Admin role denied service endpoint (HTTP $response, expected 200/429)"
fi

# Test 4: Invalid role name
log_test "Invalid role name (role escalation attempt)"
payload="{\"sub\":\"hacker\",\"role\":\"superadmin\",\"exp\":$exp,\"iat\":$now}"
token=$(generate_jwt "$payload" "$JWT_SECRET")
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$PROXY_URL/api/v1/ingest" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d '{"event_type":"test","payload":{}}')
if [[ "$response" == "403" ]] || [[ "$response" == "401" ]]; then
    log_pass "Invalid role rejected (HTTP $response)"
else
    log_fail "CRITICAL: Invalid role accepted (HTTP $response, expected 403/401)"
fi

# Test 5: Role case manipulation
log_test "Role case manipulation (ADMIN vs admin)"
payload="{\"sub\":\"hacker\",\"role\":\"ADMIN\",\"exp\":$exp,\"iat\":$now}"
token=$(generate_jwt "$payload" "$JWT_SECRET")
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$PROXY_URL/api/v1/ingest" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d '{"event_type":"test","payload":{}}')
if [[ "$response" == "403" ]] || [[ "$response" == "401" ]]; then
    log_pass "Case-manipulated role rejected (HTTP $response)"
else
    log_fail "CRITICAL: Case bypass worked (HTTP $response, expected 403/401)"
fi

# Test 6: Anonymous access to protected endpoint
log_test "No authentication on protected endpoint"
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$PROXY_URL/api/v1/ingest" \
    -H "Content-Type: application/json" \
    -d '{"event_type":"test","payload":{}}')
if [[ "$response" == "401" ]]; then
    log_pass "Anonymous access denied (HTTP 401)"
else
    log_fail "CRITICAL: Anonymous access allowed (HTTP $response, expected 401)"
fi

# Test 7: Readonly can access health (public endpoint)
log_test "Readonly role can access public endpoints"
payload="{\"sub\":\"readonly_user\",\"role\":\"readonly\",\"exp\":$exp,\"iat\":$now}"
token=$(generate_jwt "$payload" "$JWT_SECRET")
response=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$PROXY_URL/health" \
    -H "Authorization: Bearer $token")
if [[ "$response" == "200" ]]; then
    log_pass "Public endpoint accessible (HTTP 200)"
else
    log_fail "Public endpoint blocked unexpectedly (HTTP $response, expected 200)"
fi

# Summary
echo ""
echo "========================================="
echo "RBAC Security Test Summary"
echo "========================================="
echo "Total tests: $test_count"
echo -e "${GREEN}Passed: $pass_count${NC}"
echo -e "${RED}Failed: $fail_count${NC}"
echo "========================================="

if [[ $fail_count -eq 0 ]]; then
    echo -e "${GREEN}✓ All RBAC security tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some RBAC tests failed - review authorization logic${NC}"
    exit 1
fi
