#!/bin/bash
# Test Digital Ocean Spaces S3-compatible credentials

set -e

echo "=== Digital Ocean Spaces / S3 Credentials Test ==="
echo ""

# Check required env vars
MISSING=""
[ -z "${AWS_ACCESS_KEY_ID:-}" ] && MISSING="$MISSING AWS_ACCESS_KEY_ID"
[ -z "${AWS_SECRET_ACCESS_KEY:-}" ] && MISSING="$MISSING AWS_SECRET_ACCESS_KEY"
[ -z "${AWS_REGION:-}" ] && MISSING="$MISSING AWS_REGION"
[ -z "${CACHE_S3_BUCKET:-}" ] && MISSING="$MISSING CACHE_S3_BUCKET"
[ -z "${AWS_ENDPOINT_URL:-}" ] && MISSING="$MISSING AWS_ENDPOINT_URL"

if [ -n "$MISSING" ]; then
  echo "❌ Missing required environment variables:$MISSING"
  echo ""
  echo "Set these variables:"
  echo "  export AWS_ACCESS_KEY_ID='your-spaces-key'"
  echo "  export AWS_SECRET_ACCESS_KEY='your-spaces-secret'"
  echo "  export AWS_REGION='nyc3'  # or your DO region"
  echo "  export CACHE_S3_BUCKET='your-bucket-name'"
  echo "  export AWS_ENDPOINT_URL='https://nyc3.digitaloceanspaces.com'"
  exit 1
fi

echo "✓ All required environment variables are set"
echo ""
echo "Configuration:"
echo "  Region: $AWS_REGION"
echo "  Endpoint: $AWS_ENDPOINT_URL"
echo "  Bucket: $CACHE_S3_BUCKET"
echo "  Access Key: ${AWS_ACCESS_KEY_ID:0:10}..."
echo ""

# Test 1: List bucket
echo "Test 1: List bucket contents..."
if aws s3 ls "s3://${CACHE_S3_BUCKET}/" --endpoint-url "${AWS_ENDPOINT_URL}" --region "${AWS_REGION}" 2>&1 | head -10; then
  echo "✓ Successfully listed bucket"
else
  echo "❌ Failed to list bucket"
  exit 1
fi
echo ""

# Test 2: Upload a test file
echo "Test 2: Upload test file..."
TEST_FILE="/tmp/cache-test-$(date +%s).txt"
echo "Test file created at $(date)" > "$TEST_FILE"

if aws s3 cp "$TEST_FILE" "s3://${CACHE_S3_BUCKET}/test-cache-upload.txt" \
    --endpoint-url "${AWS_ENDPOINT_URL}" --region "${AWS_REGION}" --quiet; then
  echo "✓ Successfully uploaded test file"
else
  echo "❌ Failed to upload test file"
  rm -f "$TEST_FILE"
  exit 1
fi
rm -f "$TEST_FILE"
echo ""

# Test 3: Download the test file
echo "Test 3: Download test file..."
if aws s3 cp "s3://${CACHE_S3_BUCKET}/test-cache-upload.txt" "/tmp/cache-test-download.txt" \
    --endpoint-url "${AWS_ENDPOINT_URL}" --region "${AWS_REGION}" --quiet; then
  echo "✓ Successfully downloaded test file"
  cat /tmp/cache-test-download.txt
  rm -f /tmp/cache-test-download.txt
else
  echo "❌ Failed to download test file"
  exit 1
fi
echo ""

# Test 4: Delete the test file
echo "Test 4: Delete test file..."
if aws s3 rm "s3://${CACHE_S3_BUCKET}/test-cache-upload.txt" \
    --endpoint-url "${AWS_ENDPOINT_URL}" --region "${AWS_REGION}" --quiet; then
  echo "✓ Successfully deleted test file"
else
  echo "❌ Failed to delete test file"
  exit 1
fi
echo ""

echo "=== All tests passed! ==="
echo ""
echo "Your Digital Ocean Spaces credentials are working correctly."
echo "The cache-manager.sh will be able to use these credentials."
