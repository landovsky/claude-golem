# S3 Cache Setup Guide

This guide walks through setting up S3-backed dependency caching for claude-sandbox.

## Overview

S3 caching speeds up subsequent runs by caching installed dependencies (Ruby gems, Node packages) based on lockfile hashes. This is especially beneficial for Kubernetes deployments where each job starts with a fresh environment.

**Typical time savings:**
- Bundle install: 2-5 minutes → 10-30 seconds
- npm install: 1-3 minutes → 5-15 seconds

## Prerequisites

- AWS account with S3 access
- AWS CLI installed (optional, for verification)
- kubectl configured (for Kubernetes setup)

## Step 1: Create S3 Bucket

### Option A: AWS Console

1. Go to AWS S3 Console: https://s3.console.aws.amazon.com
2. Click "Create bucket"
3. Configure:
   - **Bucket name:** `my-claude-sandbox-cache` (must be globally unique)
   - **Region:** Choose your preferred region (e.g., `us-east-1`)
   - **Block Public Access:** Keep all enabled (default)
   - **Versioning:** Disabled (not needed for cache)
   - **Encryption:** Enable SSE-S3 (recommended)
4. Click "Create bucket"

### Option B: AWS CLI

```bash
# Set your bucket name and region
BUCKET_NAME="my-claude-sandbox-cache"
AWS_REGION="us-east-1"

# Create bucket
aws s3 mb "s3://${BUCKET_NAME}" --region "${AWS_REGION}"

# Enable encryption (recommended)
aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Set lifecycle policy to auto-delete old caches (optional)
aws s3api put-bucket-lifecycle-configuration \
  --bucket "${BUCKET_NAME}" \
  --lifecycle-configuration '{
    "Rules": [{
      "Id": "DeleteOldCaches",
      "Status": "Enabled",
      "Prefix": "claude-sandbox-cache/",
      "Expiration": { "Days": 30 }
    }]
  }'
```

## Step 2: Create IAM User/Policy

### Create IAM Policy

Create a policy that allows read/write access to the cache bucket:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCacheBucketAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::my-claude-sandbox-cache",
        "arn:aws:s3:::my-claude-sandbox-cache/*"
      ]
    }
  ]
}
```

### Create IAM User

1. Go to IAM Console: https://console.aws.amazon.com/iam
2. Users → Add users
3. User name: `claude-sandbox-cache`
4. Credential type: Access key
5. Attach the policy created above
6. Create user and save the Access Key ID and Secret Access Key

### Alternative: Using IAM Role (IRSA on EKS)

If running on EKS, you can use IAM Roles for Service Accounts (IRSA) instead of access keys:

```bash
# Create IAM role
eksctl create iamserviceaccount \
  --name claude-sandbox-sa \
  --namespace default \
  --cluster your-cluster \
  --attach-policy-arn arn:aws:iam::ACCOUNT_ID:policy/ClaudeSandboxCachePolicy \
  --approve

# Update K8s job to use service account
# In bin/claude-sandbox, add to YAML generation:
#   serviceAccountName: claude-sandbox-sa
```

## Step 3: Configure Local Development

For local Docker Compose usage:

```bash
# Create or edit .env.claude-sandbox in your project root
cat >> .env.claude-sandbox <<EOF
# S3 Cache Configuration
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_REGION=us-east-1
CACHE_S3_BUCKET=my-claude-sandbox-cache

# Optional: Customize cache prefix
# CACHE_S3_PREFIX=claude-sandbox-cache

# Optional: Disable compression (faster but larger)
# CACHE_COMPRESSION=false

# Optional: Enable verbose cache logging
# CACHE_VERBOSE=true
EOF

# Secure the file (contains secrets)
chmod 600 .env.claude-sandbox
```

## Step 4: Configure Kubernetes

### Option A: kubectl create secret

```bash
# Create or update claude-sandbox-secrets with cache credentials
kubectl create secret generic claude-sandbox-secrets \
  --from-literal=GITHUB_TOKEN="${GITHUB_TOKEN}" \
  --from-literal=CLAUDE_CODE_OAUTH_TOKEN="${CLAUDE_CODE_OAUTH_TOKEN}" \
  --from-literal=TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN}" \
  --from-literal=TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID}" \
  --from-literal=AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
  --from-literal=AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
  --from-literal=AWS_REGION="us-east-1" \
  --from-literal=CACHE_S3_BUCKET="my-claude-sandbox-cache" \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Option B: Using secrets.yaml

```bash
# Copy example and fill in values
cp k8s/secrets.yaml.example k8s/secrets.yaml

# Edit k8s/secrets.yaml and fill in:
# - AWS_ACCESS_KEY_ID
# - AWS_SECRET_ACCESS_KEY
# - AWS_REGION
# - CACHE_S3_BUCKET

# Apply to cluster
kubectl apply -f k8s/secrets.yaml

# Verify secret
kubectl get secret claude-sandbox-secrets -o jsonpath='{.data}' | jq -r 'keys[]'
```

### Option C: Using bin/update-secrets.sh

```bash
# Set environment variables
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_REGION="us-east-1"
export CACHE_S3_BUCKET="my-claude-sandbox-cache"

# Update cluster secret
bin/update-secrets.sh

# Verify
kubectl describe secret claude-sandbox-secrets
```

## Step 5: Verify Setup

### Test Local

```bash
# Enable verbose cache logging
export CACHE_VERBOSE=true

# First run (cache miss)
bin/claude-sandbox local "echo 'hello world'"

# Check logs for:
# [cache] Cache miss for bundle (abc123...)
# [cache] Saving to cache: s3://my-claude-sandbox-cache/claude-sandbox-cache/bundle-abc123....tar.gz
# [cache] Cache saved successfully

# Verify in S3
aws s3 ls "s3://${CACHE_S3_BUCKET}/claude-sandbox-cache/"

# Second run (cache hit)
bin/claude-sandbox local "echo 'hello world'"

# Check logs for:
# [cache] Cache hit! Downloading from S3...
# [cache] Cache restored successfully
# Ruby gems restored from S3 cache
```

### Test Remote (Kubernetes)

```bash
# First run
bin/claude-sandbox remote "echo 'hello world'"

# Check logs
bin/claude-sandbox logs

# Look for cache activity:
# [cache] Cache miss for bundle
# [cache] Cache saved successfully

# Second run with same dependencies
bin/claude-sandbox remote "echo 'hello world'"

# Should show:
# [cache] Cache hit!
# Ruby gems restored from S3 cache
```

## Monitoring and Maintenance

### View Cache Contents

```bash
# List all cached items
aws s3 ls "s3://${CACHE_S3_BUCKET}/claude-sandbox-cache/" --recursive --human-readable

# Check cache size
aws s3 ls "s3://${CACHE_S3_BUCKET}/claude-sandbox-cache/" --recursive --summarize

# Inspect specific cache entry
aws s3 cp "s3://${CACHE_S3_BUCKET}/claude-sandbox-cache/bundle-abc123def456.tar.gz" - | tar -tzf - | head -20
```

### Manual Cache Pruning

```bash
# Delete caches older than 30 days (if lifecycle not configured)
aws s3 ls "s3://${CACHE_S3_BUCKET}/claude-sandbox-cache/" --recursive | \
  awk -v date="$(date -d '30 days ago' '+%Y-%m-%d')" '$1 < date {print $4}' | \
  xargs -I {} aws s3 rm "s3://${CACHE_S3_BUCKET}/{}"
```

### Troubleshooting

**Cache not working?**

1. Check credentials:
   ```bash
   # Verify AWS credentials work
   aws s3 ls "s3://${CACHE_S3_BUCKET}/"
   ```

2. Enable verbose logging:
   ```bash
   export CACHE_VERBOSE=true
   bin/claude-sandbox local "test task"
   ```

3. Check entrypoint logs for cache messages:
   ```bash
   docker compose logs claude | grep '\[cache\]'
   ```

4. Verify environment variables are set:
   ```bash
   # Local
   docker compose run --rm claude env | grep -E 'AWS|CACHE'

   # Kubernetes
   kubectl describe secret claude-sandbox-secrets
   ```

**Cache downloads slow?**

- Use a bucket in the same region as your compute resources
- Enable S3 Transfer Acceleration (costs extra):
  ```bash
  aws s3api put-bucket-accelerate-configuration \
    --bucket "${CACHE_S3_BUCKET}" \
    --accelerate-configuration Status=Enabled
  ```

**Cache hit but install still runs?**

- This is expected if verification fails (e.g., `bundle exec ruby -e "exit 0"`)
- Check that extracted dependencies are valid
- Try disabling compression: `CACHE_COMPRESSION=false`

## Cost Estimation

S3 caching costs are typically low:

**Storage costs:**
- Average cache size: 50-200 MB per unique Gemfile.lock
- 100 unique caches × 100 MB = 10 GB
- S3 Standard: $0.023/GB/month = $0.23/month

**Transfer costs:**
- Cache download: $0.09/GB (data out)
- Cache upload: Free (data in)
- 100 downloads × 100 MB = 10 GB = $0.90/month

**Total estimated cost:** $1-2/month for moderate usage

**Cost optimization:**
- Use S3 Intelligent-Tiering for infrequently accessed caches
- Set lifecycle policy to delete old caches (30 days)
- Use same-region bucket to avoid inter-region transfer costs

## Security Considerations

1. **Use dedicated IAM user** - Don't reuse credentials from other systems
2. **Limit bucket access** - Policy should only grant access to cache bucket
3. **Enable encryption** - Use SSE-S3 or SSE-KMS
4. **Secure credentials:**
   - Local: `.env.claude-sandbox` should have `chmod 600`
   - Kubernetes: Store in secrets, not ConfigMaps
5. **Audit access** - Enable S3 access logging if needed:
   ```bash
   aws s3api put-bucket-logging \
     --bucket "${CACHE_S3_BUCKET}" \
     --bucket-logging-status '{
       "LoggingEnabled": {
         "TargetBucket": "my-logs-bucket",
         "TargetPrefix": "s3-access-logs/"
       }
     }'
   ```

## Advanced Configuration

### Using Multiple Cache Prefixes

Separate caches by environment or team:

```bash
# Production environment
CACHE_S3_PREFIX=prod/claude-sandbox-cache

# Staging environment
CACHE_S3_PREFIX=staging/claude-sandbox-cache

# Per-team caches
CACHE_S3_PREFIX=team-platform/cache
```

### Cross-Account Access

Share cache bucket across AWS accounts:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "AllowCrossAccountAccess",
    "Effect": "Allow",
    "Principal": {
      "AWS": "arn:aws:iam::OTHER-ACCOUNT-ID:user/claude-sandbox-cache"
    },
    "Action": ["s3:GetObject", "s3:PutObject"],
    "Resource": "arn:aws:s3:::my-claude-sandbox-cache/*"
  }]
}
```

### Using S3-Compatible Services

The cache manager works with any S3-compatible service (MinIO, DigitalOcean Spaces, etc.):

```bash
# Add custom endpoint to AWS CLI config
export AWS_ENDPOINT_URL=https://nyc3.digitaloceanspaces.com
export CACHE_S3_BUCKET=my-spaces-bucket
export AWS_REGION=us-east-1
```

**Note:** You may need to modify `lib/cache-manager.sh` to pass `--endpoint-url` to AWS CLI commands.

## Next Steps

- Configure cache pruning with lifecycle policies
- Set up CloudWatch metrics for cache hit rate (custom metrics)
- Consider caching other artifacts (Docker layers, build outputs)
- Extend caching to other package managers (pip, cargo) - see `docs/EXTENDING.md`
