#!/bin/bash
# test-cache-manager.sh - Unit tests for cache-manager.sh
#
# Usage: ./test/test-cache-manager.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOX_DIR="$(dirname "$SCRIPT_DIR")"

# Load cache manager
source "$SANDBOX_DIR/lib/cache-manager.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helpers
test_start() {
  TESTS_RUN=$((TESTS_RUN + 1))
  echo -e "${YELLOW}Test $TESTS_RUN:${NC} $1"
}

test_pass() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo -e "${GREEN}✓ PASS${NC}: $1\n"
}

test_fail() {
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo -e "${RED}✗ FAIL${NC}: $1\n"
}

# Create test fixtures
TEST_DIR=$(mktemp -d)
cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Test 1: cache_is_enabled without credentials
test_start "cache_is_enabled returns false when credentials missing"
unset CACHE_S3_BUCKET
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY

if cache_is_enabled; then
  test_fail "Expected cache_is_enabled to return false"
else
  test_pass "cache_is_enabled correctly returns false without credentials"
fi

# Test 2: cache_is_enabled with credentials
test_start "cache_is_enabled returns true when credentials present"
export CACHE_S3_BUCKET="test-bucket"
export AWS_ACCESS_KEY_ID="test-key"
export AWS_SECRET_ACCESS_KEY="test-secret"

if cache_is_enabled; then
  test_pass "cache_is_enabled correctly returns true with credentials"
else
  test_fail "Expected cache_is_enabled to return true"
fi

# Test 3: cache_hash calculation
test_start "cache_hash generates correct hash"
echo "test content" > "$TEST_DIR/test.lock"
HASH=$(cache_hash "$TEST_DIR/test.lock")

if [ ${#HASH} -eq 16 ]; then
  test_pass "cache_hash generates 16-character hash"
else
  test_fail "Expected 16-character hash, got ${#HASH} characters"
fi

# Test 4: cache_hash consistency
test_start "cache_hash is consistent for same content"
HASH1=$(cache_hash "$TEST_DIR/test.lock")
HASH2=$(cache_hash "$TEST_DIR/test.lock")

if [ "$HASH1" = "$HASH2" ]; then
  test_pass "cache_hash is consistent"
else
  test_fail "Expected same hash, got $HASH1 and $HASH2"
fi

# Test 5: cache_hash changes with different content
test_start "cache_hash changes for different content"
echo "different content" > "$TEST_DIR/test2.lock"
HASH1=$(cache_hash "$TEST_DIR/test.lock")
HASH2=$(cache_hash "$TEST_DIR/test2.lock")

if [ "$HASH1" != "$HASH2" ]; then
  test_pass "cache_hash correctly differs for different content"
else
  test_fail "Expected different hashes, both are $HASH1"
fi

# Test 6: cache_key format
test_start "cache_key generates correct S3 key"
export CACHE_S3_BUCKET="my-bucket"
export CACHE_S3_PREFIX="my-prefix"
export CACHE_COMPRESSION=true

KEY=$(cache_key "bundle" "abc123def456")
EXPECTED="s3://my-bucket/my-prefix/bundle-abc123def456.tar.gz"

if [ "$KEY" = "$EXPECTED" ]; then
  test_pass "cache_key generates correct format"
else
  test_fail "Expected $EXPECTED, got $KEY"
fi

# Test 7: cache_key without compression
test_start "cache_key without compression"
export CACHE_COMPRESSION=false

KEY=$(cache_key "npm" "xyz789")
EXPECTED="s3://my-bucket/my-prefix/npm-xyz789.tar"

if [ "$KEY" = "$EXPECTED" ]; then
  test_pass "cache_key correctly omits .gz when compression disabled"
else
  test_fail "Expected $EXPECTED, got $KEY"
fi

# Test 8: cache_hash with missing file
test_start "cache_hash fails gracefully with missing file"
if cache_hash "$TEST_DIR/nonexistent.lock" 2>/dev/null; then
  test_fail "Expected cache_hash to fail with missing file"
else
  test_pass "cache_hash correctly fails with missing file"
fi

# Summary
echo ""
echo "========================================"
echo "Test Summary:"
echo "  Total:  $TESTS_RUN"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
  echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
else
  echo -e "  Failed: $TESTS_FAILED"
fi
echo "========================================"

if [ $TESTS_FAILED -gt 0 ]; then
  exit 1
fi

echo -e "${GREEN}All tests passed!${NC}"
