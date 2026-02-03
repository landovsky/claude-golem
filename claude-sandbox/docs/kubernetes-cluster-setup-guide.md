# Kubernetes Cluster Setup Guide

This guide covers configuring an existing Kubernetes cluster to run claude-sandbox remote execution jobs. It assumes you already have a functioning Kubernetes cluster (k3s, EKS, GKE, AKS, etc.).

## Prerequisites

- Existing Kubernetes cluster (operational and accessible)
- `kubectl` installed locally and configured to access your cluster
- Docker Hub account (or other container registry)
- GitHub personal access token with `repo` scope
- Claude authentication (OAuth token or API key)

## Quick Setup

### 1. Verify Cluster Access

```bash
# Verify kubectl can reach your cluster
kubectl cluster-info
kubectl get nodes

# Check you have permissions to create secrets and jobs
kubectl auth can-i create secrets
kubectl auth can-i create jobs
```

### 2. Create Secrets

Claude-sandbox requires a Kubernetes secret containing authentication credentials:

```bash
# Set your credentials
export GITHUB_TOKEN="ghp_..."                      # GitHub personal access token
export CLAUDE_CODE_OAUTH_TOKEN="sk-ant-oat01-..."  # From: claude setup-token
# OR use API key instead:
# export ANTHROPIC_API_KEY="sk-ant-api03-..."

# Optional: Telegram notifications
export TELEGRAM_BOT_TOKEN="123456789:ABC..."
export TELEGRAM_CHAT_ID="-100..."

# Create the secret in your cluster
kubectl create secret generic claude-sandbox-secrets \
  --from-literal=GITHUB_TOKEN="$GITHUB_TOKEN" \
  --from-literal=CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN" \
  --from-literal=TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}" \
  --from-literal=TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# Verify secret was created
kubectl get secret claude-sandbox-secrets
```

**Note on REPO_URL:** The secret does NOT need to include `REPO_URL`. This is automatically detected from your current git directory when running `bin/claude-sandbox remote`.

### 3. Verify Docker Image Access

The default public image is available at `landovsky/claude-sandbox:latest`. For forks, the image name adapts automatically to `yourname/claude-sandbox:latest` based on your repository owner.

```bash
# Test pulling the image (optional)
docker pull landovsky/claude-sandbox:latest

# For custom images, see "Building Custom Images" below
```

### 4. Test Remote Execution

```bash
# From your project directory
cd ~/your-rails-project

# Run a simple task
~/.claude/claude-sandbox/bin/claude-sandbox remote "list files and show git status"

# Watch the logs
~/.claude/claude-sandbox/bin/claude-sandbox logs
```

That's it! Your cluster is configured for remote execution.

## Authentication Options

### Option 1: OAuth Token (Recommended)

Uses your existing Claude subscription. Token is valid for 1 year.

```bash
# Run once to generate token
claude setup-token

# Follow browser prompts to authenticate
# Save the token that starts with: sk-ant-oat01-...

# Use in secrets
export CLAUDE_CODE_OAUTH_TOKEN="sk-ant-oat01-..."
```

### Option 2: API Key

Pay-as-you-go API usage. Get from console.anthropic.com.

```bash
export ANTHROPIC_API_KEY="sk-ant-api03-..."

# Update secret
kubectl create secret generic claude-sandbox-secrets \
  --from-literal=ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  --from-literal=GITHUB_TOKEN="$GITHUB_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Namespace Configuration

By default, claude-sandbox uses your current kubectl context's namespace. To use a specific namespace:

```bash
# Create namespace
kubectl create namespace claude-sandbox

# Use it in your context
kubectl config set-context --current --namespace=claude-sandbox

# Or specify per-command
kubectl -n claude-sandbox get pods
```

## Resource Limits

The default job configuration sets reasonable limits:

```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

To adjust these, edit the job template in your deployment or set custom values before running:

```bash
# Jobs are generated dynamically - you can modify the template
# in bin/claude-sandbox script's generate_k8s_job_yaml() function
```

## Storage Configuration

Claude-sandbox jobs are ephemeral - they clone the repository fresh each time and don't persist state between runs. No persistent volumes are required.

**What gets stored:**
- Nothing persists after job completion
- All work is pushed to git remote before exit
- Logs are available via kubectl for completed jobs (TTL: 3600s)

**Temporary storage:**
- Each job gets ephemeral pod storage for git clone and build artifacts
- `/dev/shm` emptyDir for Chrome (system tests)

## Building Custom Images

For custom agents, dependencies, or private registries:

### Local Build

```bash
cd ~/.claude/claude-sandbox

# Build with your ~/.claude/agents baked in
bin/claude-sandbox build

# Tag for your registry
docker tag claude-sandbox:latest yourusername/claude-sandbox:latest

# Push to Docker Hub
docker push yourusername/claude-sandbox:latest

# Use custom image
export CLAUDE_IMAGE="yourusername/claude-sandbox:latest"
bin/claude-sandbox remote "your task"
```

### CI/CD Build (Automated)

For forks, GitHub Actions automatically builds and pushes images on release tags:

1. **Configure GitHub secrets:**
   - `DOCKERHUB_USERNAME`: Your Docker Hub username
   - `DOCKERHUB_TOKEN`: Docker Hub access token

2. **Create a release:**
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

3. **Use the versioned image:**
   ```bash
   export CLAUDE_IMAGE="yourusername/claude-sandbox:1.0.0"
   ```

See [README.md CI/CD section](../README.md#cicd---automated-image-builds) for details.

## Private Container Registries

If using a private registry (not Docker Hub):

```bash
# Create registry credentials secret
kubectl create secret docker-registry regcred \
  --docker-server=your-registry.example.com \
  --docker-username=your-username \
  --docker-password=your-password \
  --docker-email=your-email@example.com

# Update job template to reference imagePullSecrets
# (requires modifying bin/claude-sandbox script)
```

## Service Detection

Claude-sandbox automatically detects which services (PostgreSQL, Redis) your project needs and only provisions those sidecars. This happens transparently:

**Detection works for:**
- Local git repositories (via `git archive`)
- Git servers that support `git archive` protocol
- Scans `Gemfile` for `pg`, `redis`, `sidekiq` gems
- Scans `package.json` for postgres/redis clients

**Fallback behavior:**
- GitHub.com HTTPS URLs: Cannot use `git archive`, falls back to all services
- Detection failures: Safe default includes all services
- No performance impact: Detection happens pre-launch

**Verify detection:**
```bash
# Check job's container count
kubectl get pod <pod-name> -o json | jq '.spec.containers | length'

# 1 = claude only
# 2 = claude + one sidecar
# 3 = claude + both sidecars

# Check environment variables
kubectl get pod <pod-name> -o json | jq '.spec.containers[0].env[] | select(.name=="DATABASE_URL" or .name=="REDIS_URL")'
```

## Monitoring Jobs

### List running jobs
```bash
kubectl get jobs -l app=claude-sandbox
kubectl get pods -l app=claude-sandbox
```

### View logs
```bash
# Using convenience script
bin/claude-sandbox logs

# Or directly with kubectl
kubectl logs -f <pod-name> -c claude
```

### Check job status
```bash
kubectl describe job <job-name>
kubectl describe pod <pod-name>
```

### Clean up completed jobs
```bash
# Using convenience script
bin/claude-sandbox clean

# Or manually
kubectl delete jobs -l app=claude-sandbox,status=complete
```

## Troubleshooting

### Secret Not Found

```bash
# Verify secret exists
kubectl get secret claude-sandbox-secrets

# Check secret contents (base64 encoded)
kubectl get secret claude-sandbox-secrets -o yaml

# Recreate if needed
kubectl delete secret claude-sandbox-secrets
# ... run create command again
```

### Image Pull Errors

```bash
# Check if image exists and is accessible
docker pull $CLAUDE_IMAGE

# Check pod events
kubectl describe pod <pod-name> | grep -A 10 Events

# For private registries, verify imagePullSecrets
kubectl get pods <pod-name> -o yaml | grep -A 5 imagePullSecrets
```

### Pod Crashes or OOMKilled

```bash
# Check resource usage
kubectl describe pod <pod-name> | grep -A 10 "Limits:\|Requests:"

# Check events
kubectl describe pod <pod-name> | grep OOMKilled

# Increase memory limits in job template if needed
```

### Jobs Stay Pending

```bash
# Check for resource constraints
kubectl describe pod <pod-name> | grep -A 10 Events

# Check node resources
kubectl top nodes

# Check for PodSchedulingFailed events
kubectl get events --sort-by=.lastTimestamp
```

### Sidecar Health Issues

```bash
# Check postgres sidecar
kubectl logs <pod-name> -c postgres-sidecar
kubectl exec <pod-name> -c claude -- pg_isready -h localhost

# Check redis sidecar
kubectl logs <pod-name> -c redis-sidecar
kubectl exec <pod-name> -c claude -- redis-cli -h localhost ping
```

## Security Considerations

### Secret Management

- Use Kubernetes secrets for sensitive values (tokens, passwords)
- Consider using sealed secrets or external secret operators for production
- Rotate tokens regularly
- Use fine-grained GitHub tokens with minimal required scopes

### Network Policies

To restrict pod network access:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: claude-sandbox-netpol
spec:
  podSelector:
    matchLabels:
      app: claude-sandbox
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector: {}  # Allow pod-to-pod (sidecars)
  - to:  # Allow external git/API access
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 22
```

### Pod Security Standards

Claude-sandbox runs as non-root user `claude` (UID 1000):

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault
```

## Advanced Configuration

### Custom Ruby Versions

The image automatically detects Ruby version from `.ruby-version` in your repository:

- Supports Ruby 3.2, 3.3, 3.4
- Uses tagged images: `claude-sandbox:ruby-3.3`
- Falls back to Ruby 3.4 (latest) if not specified

See [RUBY-VERSIONS-management.md](RUBY-VERSIONS-management.md) for details.

### SOPS Encrypted Secrets

For project-specific secrets that should live in your repository:

1. Set up age encryption keys
2. Create `.env.sops` in your project
3. Create `age-key` secret in cluster
4. Claude-sandbox automatically decrypts at runtime

See [SOPS-setup.md](SOPS-setup.md) for complete guide.

### Telegram Notifications

Get notified when jobs complete:

```bash
# Create bot with @BotFather
# Get chat ID from @userinfobot

export TELEGRAM_BOT_TOKEN="123456789:ABC..."
export TELEGRAM_CHAT_ID="-100..."

# Update secret
kubectl create secret generic claude-sandbox-secrets \
  --from-literal=TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN" \
  --from-literal=TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID" \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Migration from Docker Compose

If you're currently using local execution and want to move to k8s:

```bash
# Before: Local execution
cd ~/project
bin/claude-sandbox local "fix bug"

# After: Remote execution (same environment)
cd ~/project
bin/claude-sandbox remote "fix bug"
```

**Key differences:**
- Same Docker image, same environment
- Dynamic sidecar provisioning works identically
- Logs accessed via kubectl instead of docker compose
- Jobs are ephemeral (auto-cleanup after 3600s TTL)
- Better resource isolation and limits

## Cluster Requirements

**Minimum specifications:**
- Kubernetes 1.19+
- At least 2 CPU cores available per job
- At least 4GB memory available per job
- Container runtime supporting Docker images (containerd, CRI-O, Docker)
- Internet access for git clone and API calls

**Tested on:**
- k3s 1.28+
- Amazon EKS
- Google GKE
- Azure AKS
- DigitalOcean Kubernetes

## Next Steps

- Review [README.md](../README.md) for full feature documentation
- Check [TESTING.md](../k8s/TESTING.md) for testing procedures
- Set up [SOPS encryption](SOPS-setup.md) for secrets
- Configure [Telegram notifications](../README.md#telegram-notifications)
- Explore [Ruby version management](RUBY-VERSIONS-management.md)
