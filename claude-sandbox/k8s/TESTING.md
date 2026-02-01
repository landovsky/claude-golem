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

## Phase 2: Test Dynamic Sidecar Detection

The `cmd_remote()` function now dynamically generates job YAML with only the required sidecars based on repository analysis.

### Test with different repository types:

**No services needed (static site, simple scripts):**
```bash
export REPO_URL="https://github.com/yourusername/static-site.git"
bin/claude-sandbox remote "list files and show repository structure"

# Verify: Job should have only claude container, no sidecars
kubectl get pod <pod-name> -o json | jq '.spec.containers | length'
# Expected: 1
```

**Only PostgreSQL needed (Rails app with pg gem):**
```bash
export REPO_URL="https://github.com/yourusername/rails-app-with-pg.git"
bin/claude-sandbox remote "run rails db:migrate and show status"

# Verify: Job should have claude + postgres-sidecar
kubectl get pod <pod-name> -o json | jq '.spec.containers | length'
# Expected: 2
kubectl get pod <pod-name> -o json | jq '.spec.containers[].name'
# Expected: "claude", "postgres-sidecar"
```

**Only Redis needed (app with redis gem, no database):**
```bash
export REPO_URL="https://github.com/yourusername/redis-only-app.git"
bin/claude-sandbox remote "test redis connection"

# Verify: Job should have claude + redis-sidecar
kubectl get pod <pod-name> -o json | jq '.spec.containers | length'
# Expected: 2
```

**Both services needed:**
```bash
export REPO_URL="https://github.com/yourusername/full-rails-app.git"
bin/claude-sandbox remote "run full test suite"

# Verify: Job should have claude + postgres-sidecar + redis-sidecar
kubectl get pod <pod-name> -o json | jq '.spec.containers | length'
# Expected: 3
```

### Verify environment variables:

Check that DATABASE_URL and REDIS_URL are only included when sidecars are present:

```bash
# No services
kubectl get pod <pod-name> -o json | jq '.spec.containers[0].env[] | select(.name=="DATABASE_URL" or .name=="REDIS_URL")'
# Expected: No output

# Only postgres
kubectl get pod <pod-name> -o json | jq '.spec.containers[0].env[] | select(.name=="DATABASE_URL")'
# Expected: DATABASE_URL present
kubectl get pod <pod-name> -o json | jq '.spec.containers[0].env[] | select(.name=="REDIS_URL")'
# Expected: No output

# Only redis
kubectl get pod <pod-name> -o json | jq '.spec.containers[0].env[] | select(.name=="REDIS_URL")'
# Expected: REDIS_URL present
kubectl get pod <pod-name> -o json | jq '.spec.containers[0].env[] | select(.name=="DATABASE_URL")'
# Expected: No output
```

### Test fallback behavior:

**Detection fails (GitHub.com HTTPS URL without local clone):**
```bash
# From a directory that's NOT the target repository
cd /tmp
export REPO_URL="https://github.com/yourusername/some-repo.git"
bin/claude-sandbox remote "test task"

# Expected log output: "Service detection failed, including all sidecars"
# Verify: Job should have all 3 containers (fail-open)
kubectl get pod <pod-name> -o json | jq '.spec.containers | length'
# Expected: 3
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

**Basic functionality:**
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

**Dynamic sidecar detection:**
- [ ] Job with no services has 1 container (claude only)
- [ ] Job with only postgres has 2 containers (claude + postgres-sidecar)
- [ ] Job with only redis has 2 containers (claude + redis-sidecar)
- [ ] Job with both services has 3 containers (claude + both sidecars)
- [ ] DATABASE_URL only present when postgres-sidecar included
- [ ] REDIS_URL only present when redis-sidecar included
- [ ] Detection failure falls back to all sidecars (logged as warning)
- [ ] Local repository detection works correctly
- [ ] Git archive detection works for supported git servers
- [ ] GitHub.com HTTPS URLs fall back to all sidecars (expected limitation)

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
