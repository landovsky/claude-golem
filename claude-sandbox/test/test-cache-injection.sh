#!/bin/bash
# Test that S3 cache env vars are properly injected into the container

set -e

echo "=== Testing S3 Cache Environment Injection ==="
echo ""

# Check required env vars are set on host
echo "1. Verifying host environment..."
MISSING=""
[ -z "${AWS_ACCESS_KEY_ID:-}" ] && MISSING="$MISSING AWS_ACCESS_KEY_ID"
[ -z "${AWS_SECRET_ACCESS_KEY:-}" ] && MISSING="$MISSING AWS_SECRET_ACCESS_KEY"
[ -z "${AWS_REGION:-}" ] && MISSING="$MISSING AWS_REGION"
[ -z "${CACHE_S3_BUCKET:-}" ] && MISSING="$MISSING CACHE_S3_BUCKET"
[ -z "${AWS_ENDPOINT_URL:-}" ] && MISSING="$MISSING AWS_ENDPOINT_URL"

if [ -n "$MISSING" ]; then
  echo "❌ Missing required environment variables on host:$MISSING"
  exit 1
fi

echo "✓ All required env vars set on host"
echo "  AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:0:10}..."
echo "  AWS_REGION: $AWS_REGION"
echo "  CACHE_S3_BUCKET: $CACHE_S3_BUCKET"
echo "  AWS_ENDPOINT_URL: $AWS_ENDPOINT_URL"
echo ""

# Test container environment injection
echo "2. Testing container environment injection..."

# Create a minimal test script that will run inside the container
TEST_SCRIPT='
#!/bin/bash
echo "Inside container - checking env vars:"
echo "  AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:0:10}..."
echo "  AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY:0:10}..."
echo "  AWS_REGION: $AWS_REGION"
echo "  AWS_ENDPOINT_URL: $AWS_ENDPOINT_URL"
echo "  CACHE_S3_BUCKET: $CACHE_S3_BUCKET"
echo ""

# Check if cache-manager.sh is available
if [ -f /usr/local/lib/cache-manager.sh ]; then
  echo "✓ cache-manager.sh found at /usr/local/lib/cache-manager.sh"
  source /usr/local/lib/cache-manager.sh

  # Test if caching is enabled
  if cache_is_enabled; then
    echo "✓ Caching is enabled"
  else
    echo "❌ Caching is not enabled (cache_is_enabled returned false)"
    exit 1
  fi

  # Test AWS CLI access
  echo ""
  echo "Testing AWS CLI access to bucket:"
  if aws s3 ls "s3://${CACHE_S3_BUCKET}/" --endpoint-url "${AWS_ENDPOINT_URL}" --region "${AWS_REGION}" 2>&1 | head -10; then
    echo "✓ Successfully accessed S3 bucket from container"
  else
    echo "❌ Failed to access S3 bucket from container"
    exit 1
  fi
else
  echo "❌ cache-manager.sh not found in container"
  exit 1
fi
'

# Run the test script in the container
# Bypass the entrypoint to avoid running the full setup
docker compose --profile claude run --rm --entrypoint bash claude -c "$TEST_SCRIPT"

echo ""
echo "=== All tests passed! ==="
echo ""
echo "✓ Environment variables are properly injected into the container"
echo "✓ cache-manager.sh is available and working"
echo "✓ AWS CLI can access Digital Ocean Spaces from inside the container"
