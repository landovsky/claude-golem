# Claude Sandbox K8s Testing Guide

This guide walks through testing the claude-sandbox Kubernetes deployment, starting with a minimal configuration and progressively adding complexity.

## Prerequisites

1. **Access to k8s cluster**: ✓ (k3s at 46.224.10.159:6443)
2. **kubectl configured**: ✓
3. **Docker image built and pushed**
4. **Secrets configured**

## Phase 1: Minimal Deployment (No Services)

### Step 1: Image Available

Public image ready to use: `landovsky/claude-sandbox:latest` (auto-detected from repository owner for forks)

To use your own custom image:
```bash
cd ~/.claude/claude-sandbox

# Build image with your agents
bin/claude-sandbox build

# Tag for your registry
export CLAUDE_REGISTRY="yourusername"  # Docker Hub username
docker tag claude-sandbox:latest $CLAUDE_REGISTRY/claude-sandbox:latest

# Push to registry
docker push $CLAUDE_REGISTRY/claude-sandbox:latest

# Override default image
export CLAUDE_IMAGE="$CLAUDE_REGISTRY/claude-sandbox:latest"
```

### Step 2: Create Secrets

```bash
# Set your credentials
export GITHUB_TOKEN="ghp_..."
export CLAUDE_CODE_OAUTH_TOKEN="sk-ant-oat01-..."  # from: claude setup-token
export REPO_URL="https://github.com/yourusername/test-repo.git"

# Optional: Telegram notifications
export TELEGRAM_BOT_TOKEN="123456789:ABC..."
export TELEGRAM_CHAT_ID="-100..."

# Create secret
kubectl create secret generic claude-sandbox-secrets \
  --from-literal=GITHUB_TOKEN="$GITHUB_TOKEN" \
  --from-literal=CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN" \
  --from-literal=REPO_URL="$REPO_URL" \
  --from-literal=TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}" \
  --from-literal=TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# Verify
kubectl get secret claude-sandbox-secrets
```

### Step 3: Run Test Job

```bash
cd ~/.claude/claude-sandbox/k8s

# Run test with simple task
# Auto-detects image name from git remote origin (e.g., landovsky/claude-sandbox:latest)
# Falls back to landovsky/claude-sandbox:latest if detection fails
./test-deployment.sh test "list files in the repository and show git status"

# Or override with your custom image:
# export CLAUDE_IMAGE="yourusername/claude-sandbox:latest"
# ./test-deployment.sh test "..."
```

**Expected Output:**
- Job creates successfully
- Pod starts and pulls image
- Container executes entrypoint.sh
- Clones repository
- Runs Claude with the task
- Streams output
- Completes successfully

### Step 4: Verify Results

```bash
# Check job status
kubectl get jobs -l test=true

# Check pod status
kubectl get pods -l app=claude-sandbox

# View logs if needed
kubectl logs <pod-name> -c claude

# Clean up
./test-deployment.sh cleanup
```

## Phase 2: Add Database Services

Once Phase 1 works, uncomment the sidecars in `job-template-test.yaml`:

```bash
# Edit job-template-test.yaml
# Uncomment the postgres-sidecar and redis-sidecar sections
# Uncomment DATABASE_URL and REDIS_URL env vars
```

Then test with a Rails project that needs database:

```bash
export REPO_URL="https://github.com/yourusername/rails-app.git"
kubectl delete secret claude-sandbox-secrets
kubectl create secret generic claude-sandbox-secrets \
  --from-literal=GITHUB_TOKEN="$GITHUB_TOKEN" \
  --from-literal=CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN" \
  --from-literal=REPO_URL="$REPO_URL" \
  --from-literal=TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}" \
  --from-literal=TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

./test-deployment.sh test "run rails db:migrate and show status"
```

## Phase 3: Production Template

Once Phase 2 works, update the main `job-template.yaml` with:
1. ✓ Removed init container
2. Database name from secrets (not hardcoded)
3. Readiness checks in entrypoint.sh

## Troubleshooting

### Image Pull Errors

```bash
# Check if image exists
docker pull $CLAUDE_IMAGE

# Check image pull secrets
kubectl get secrets ghcr-secret -o yaml

# Add imagePullSecrets to job template if needed
```

### Secret Not Found

```bash
# Verify secret exists and has correct keys
kubectl get secret claude-sandbox-secrets -o yaml

# Recreate if needed
kubectl delete secret claude-sandbox-secrets
# ... create command from Step 2
```

### Pod Crashes or OOMKilled

```bash
# Check pod events
kubectl describe pod <pod-name>

# Check resource limits
kubectl get pod <pod-name> -o yaml | grep -A 5 resources

# Adjust memory limits in job-template-test.yaml if needed
```

### Entrypoint Fails

```bash
# View full logs
kubectl logs <pod-name> -c claude

# Check specific sections
kubectl logs <pod-name> -c claude | grep -A 10 "Repository Setup"
kubectl logs <pod-name> -c claude | grep -A 10 "Dependency Installation"
kubectl logs <pod-name> -c claude | grep -A 10 "Claude Code Session"
```

### Database Connection Issues (Phase 2)

```bash
# Check postgres sidecar logs
kubectl logs <pod-name> -c postgres-sidecar

# Check if postgres is ready
kubectl exec <pod-name> -c claude -- pg_isready -h localhost -U claude

# Check redis
kubectl exec <pod-name> -c claude -- redis-cli -h localhost ping
```

## Test Checklist

- [ ] Image builds successfully
- [ ] Image pushes to registry
- [ ] Secrets created in cluster
- [ ] Test job creates successfully
- [ ] Pod starts and image pulls
- [ ] Repository clones successfully
- [ ] Dependencies install (if applicable)
- [ ] Claude executes task
- [ ] Output streams correctly
- [ ] Job completes successfully
- [ ] Telegram notification sent (if configured)
- [ ] Job cleanup works (TTL)

## Current Status

**Completed:**
- ✓ Removed broken init container pattern
- ✓ Created test template without services
- ✓ Created test script

**To Do:**
- [ ] Build and push image
- [ ] Create secrets
- [ ] Run Phase 1 test
- [ ] Add database readiness checks to entrypoint.sh
- [ ] Fix hardcoded database name
- [ ] Run Phase 2 test with services
- [ ] Update production template
