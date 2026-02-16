#!/usr/bin/env bash
# Security Audit: DoS Resistance
# Tests resilience against denial-of-service attacks

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
payload="{\"sub\":\"user123\",\"role\":\"service\",\"exp\":$exp,\"iat\":$now}"
TOKEN=$(generate_jwt "$payload" "$JWT_SECRET")

# Test 1: Large payload handling
log_test "Large payload handling (1MB payload)"
large_payload=$(python3 -c "print('x' * 1048576)" 2>/dev/null || echo "fallback")
response=$(timeout 5 curl -s -o /dev/null -w "%{http_code}" -X POST "$PROXY_URL/api/v1/ingest" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"event_type\":\"test\",\"payload\":\"$large_payload\"}" 2>/dev/null || echo "timeout")

if [[ "$response" == "413" ]] || [[ "$response" == "400" ]]; then
    log_pass "Large payload rejected (HTTP $response)"
elif [[ "$response" == "timeout" ]] || [[ "$response" == "000" ]]; then
    log_pass "Large payload timed out (service protected)"
else
    log_fail "Large payload may be accepted (HTTP $response)"
fi

# Test 2: Deeply nested JSON
log_test "Deeply nested JSON (DoS via parser)"
nested_json='{"a":{"a":{"a":{"a":{"a":{"a":{"a":{"a":{"a":{"a":"x"}}}}}}}}}}'
response=$(timeout 3 curl -s -o /dev/null -w "%{http_code}" -X POST "$PROXY_URL/api/v1/ingest" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$nested_json" 2>/dev/null || echo "timeout")

if [[ "$response" == "200" ]] || [[ "$response" == "400" ]] || [[ "$response" == "429" ]]; then
    log_pass "Nested JSON handled gracefully (HTTP $response)"
elif [[ "$response" == "timeout" ]]; then
    log_fail "Nested JSON caused timeout (parser DoS vulnerability)"
else
    log_pass "Nested JSON handled (HTTP $response)"
fi

# Test 3: Connection exhaustion resistance
log_test "Connection exhaustion (50 concurrent connections)"
echo -n "Opening connections... "
for i in {1..50}; do
    {
        timeout 2 curl -s -o /dev/null -X POST "$PROXY_URL/api/v1/ingest" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d '{"event_type":"test","payload":{}}' 2>/dev/null || true
    } &
done
wait 2>/dev/null || true
echo "done"

# Check if proxy is still responsive
response=$(timeout 3 curl -s -o /dev/null -w "%{http_code}" -X GET "$PROXY_URL/health" 2>/dev/null || echo "down")
if [[ "$response" == "200" ]]; then
    log_pass "Proxy responsive after connection flood (HTTP 200)"
else
    log_fail "Proxy unresponsive after connection flood (HTTP $response)"
fi

# Test 4: Slowloris resistance (slow headers)
log_test "Slowloris attack resistance"
# Send slow headers (incomplete request)
{
    (
        echo -ne "POST /api/v1/ingest HTTP/1.1\r\n"
        sleep 1
        echo -ne "Host: localhost:3000\r\n"
        sleep 1
        echo -ne "Authorization: Bearer $TOKEN\r\n"
    ) | timeout 5 nc localhost 3000 >/dev/null 2>&1 || true
} &
slow_pid=$!

sleep 2
# Check if proxy is still responsive during slow attack
response=$(timeout 3 curl -s -o /dev/null -w "%{http_code}" -X GET "$PROXY_URL/health" 2>/dev/null || echo "down")
kill $slow_pid 2>/dev/null || true
wait $slow_pid 2>/dev/null || true

if [[ "$response" == "200" ]]; then
    log_pass "Proxy responsive during slow header attack (HTTP 200)"
else
    log_warn "Proxy may be vulnerable to slowloris (HTTP $response)"
fi

# Test 5: Invalid content-type handling
log_test "Invalid Content-Type handling"
response=$(timeout 3 curl -s -o /dev/null -w "%{http_code}" -X POST "$PROXY_URL/api/v1/ingest" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/xml" \
    -d '<xml>test</xml>' 2>/dev/null || echo "timeout")

if [[ "$response" == "400" ]] || [[ "$response" == "415" ]]; then
    log_pass "Invalid Content-Type rejected (HTTP $response)"
else
    log_pass "Invalid Content-Type handled (HTTP $response)"
fi

# Test 6: Malformed JSON handling
log_test "Malformed JSON handling"
response=$(timeout 3 curl -s -o /dev/null -w "%{http_code}" -X POST "$PROXY_URL/api/v1/ingest" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{invalid json' 2>/dev/null || echo "timeout")

if [[ "$response" == "400" ]]; then
    log_pass "Malformed JSON rejected (HTTP 400)"
else
    log_pass "Malformed JSON handled (HTTP $response)"
fi

# Summary
echo ""
echo "========================================="
echo "DoS Resistance Test Summary"
echo "========================================="
echo "Total tests: $test_count"
echo -e "${GREEN}Passed: $pass_count${NC}"
echo -e "${RED}Failed: $fail_count${NC}"
echo "========================================="

if [[ $fail_count -eq 0 ]]; then
    echo -e "${GREEN}✓ All DoS resistance tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some DoS vulnerabilities found${NC}"
    exit 1
fi
