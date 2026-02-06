# Claude Sandbox

Run Claude Code autonomously in an isolated Docker environment with full permissions (`--dangerously-skip-permissions`).

## Current Scope: Rails Ecosystem

This sandbox is currently optimized for **Ruby on Rails projects**. It includes PostgreSQL (with PostGIS), Redis, Chrome for system tests, and supports multiple Ruby versions. After battle testing in production Rails environments, the architecture can be revisioned to support other ecosystems (Node.js, Python, Go, etc.) through similar patterns.

## Why?

When you want Claude to work on tasks without supervision:
- **Isolation**: Fresh git clone, doesn't touch your local checkout
- **Safety**: Protected branches (main/master/production) can't be force-pushed
- **Notifications**: Get Telegram alerts when Claude finishes or gets stuck
- **Reproducibility**: Same environment locally and remotely
- **Full stack**: PostgreSQL, Redis, Chrome (for system tests) included
- **SOPS Integration**: Encrypted secrets in your repo, no manual k8s secret management

## Architecture & Documentation

For a comprehensive understanding of how claude-sandbox works:

📖 **[Architecture Documentation](docs/ARCHITECTURE.md)** - Complete system architecture, components, deployment models, and key mechanisms

Additional documentation:
- **[Architecture Decisions](docs/ARCHITECTURE-DECISIONS.md)** - Historical record of major design decisions
- **[Extending](docs/EXTENDING.md)** - How to add new languages, databases, and services
- **[Kubernetes Setup](docs/kubernetes-cluster-setup-guide.md)** - Cluster configuration guide
- **[SOPS Setup](docs/SOPS-setup.md)** - Encrypted secrets management
- **[Ruby Versions](docs/RUBY-VERSIONS-management.md)** - Managing multiple Ruby versions
- **[S3 Cache Setup](docs/S3-CACHE-SETUP.md)** - S3-backed dependency caching configuration

## Quick Start

### Authentication

Choose one authentication method:

**Option 1: OAuth Token (Recommended)**
- Uses your Claude subscription
- Valid for 1 year
- Setup once: `claude setup-token`

```bash
export CLAUDE_CODE_OAUTH_TOKEN="sk-ant-oat01-..."  # From setup-token
```

**Option 2: API Key**
- Pay-as-you-go API usage
- Get from console.anthropic.com

```bash
export ANTHROPIC_API_KEY="sk-ant-api03-..."
```

### Local (Docker Compose)

```bash
# Set required environment variables
export GITHUB_TOKEN="ghp_..."
export CLAUDE_CODE_OAUTH_TOKEN="sk-ant-oat01-..."  # Or use ANTHROPIC_API_KEY

# REPO_URL can be auto-detected from current git directory
# Or set explicitly:
export REPO_URL="https://github.com/you/your-repo.git"

# Optional: Telegram notifications
export TELEGRAM_BOT_TOKEN="123456789:ABC..."
export TELEGRAM_CHAT_ID="-100..."

# Run Claude on a task
bin/claude-sandbox local "fix the authentication bug in login controller"
```

### Remote (Kubernetes/k3s)

**Prerequisites:**
- Existing Kubernetes cluster (k3s, EKS, GKE, AKS, etc.)
- kubectl configured to access your cluster
- See [docs/kubernetes-cluster-setup-guide.md](docs/kubernetes-cluster-setup-guide.md) for detailed cluster configuration

**Features:**
- ✅ Basic job execution (clone repo, run Claude)
- ✅ Dynamic sidecar provisioning (only includes required services)
- ✅ SOPS encrypted secrets
- ✅ .env.claude-sandbox plaintext config
- ✅ REPO_URL auto-detection
- ✅ Parallel deployments

**Dynamic Sidecars:**
K8s jobs now use the same service detection as local Docker Compose. Only required sidecars are included:
- Scans repository before job creation
- Conditionally includes postgres-sidecar only when needed
- Conditionally includes redis-sidecar only when needed
- Falls back to all sidecars if detection fails (safe default)
- Same git archive limitation as local (GitHub.com HTTPS not supported)

See [k8s/TESTING.md](k8s/TESTING.md) for testing details and [docs/kubernetes-cluster-setup-guide.md](docs/kubernetes-cluster-setup-guide.md) for cluster setup.

```bash
# First, create secrets in your cluster
# Note: REPO_URL is optional in secret if using auto-detection
kubectl create secret generic claude-sandbox-secrets \
  --from-literal=GITHUB_TOKEN="$GITHUB_TOKEN" \
  --from-literal=CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN" \
  --from-literal=TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN" \
  --from-literal=TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID" \
  --from-literal=AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
  --from-literal=AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
  --from-literal=AWS_REGION="us-east-1" \
  --from-literal=CACHE_S3_BUCKET="my-claude-sandbox-cache"

# Images are automatically built via CI/CD on release tags
# Image name uses repository owner (auto-detects from fork)
# Use the latest stable image from Docker Hub:
# landovsky/claude-sandbox:latest (or specific version like :1.0.0)
# For forks: yourname/claude-sandbox:latest

# Run remotely - REPO_URL auto-detected from current directory
cd ~/your-project
bin/claude-sandbox remote "implement user profile page"
# Auto-detects: REPO_URL from 'git remote get-url origin'
# Auto-detects: REPO_BRANCH from 'git branch --show-current'

# Or override with explicit values:
# REPO_URL="https://github.com/other/repo.git" bin/claude-sandbox remote "task"

# Watch logs
bin/claude-sandbox logs
```

**For detailed cluster setup instructions**, see [docs/kubernetes-cluster-setup-guide.md](docs/kubernetes-cluster-setup-guide.md).

## CI/CD - Automated Image Builds

Docker images are automatically built and pushed to Docker Hub when a semantic version tag is created.

### How It Works

1. **Tag creation triggers build**: When you push a tag matching `v*.*.*` (e.g., `v1.0.0`, `v2.3.4`), GitHub Actions automatically:
   - Builds the image using `${{ github.repository_owner }}/claude-sandbox` (adapts to forks)
   - Pushes with both version tag (e.g., `1.0.0`) and `latest`
   - Currently builds for amd64 only (arm64 requires Dockerfile changes for SOPS/age)

2. **PR validation**: Pull requests that modify Docker-related files trigger a test build to catch issues early

### Required GitHub Secrets

For automated builds to work, the following secrets must be configured in the repository:

- `DOCKERHUB_USERNAME`: Your Docker Hub username
- `DOCKERHUB_TOKEN`: Docker Hub access token (create at hub.docker.com/settings/security)

### Creating a Release

**Option 1: Manual tag**
```bash
git tag v1.0.0
git push origin v1.0.0
```

**Option 2: Using release-it** (when configured)
```bash
npx release-it
```

### Manual Build (Local Development)

For local testing or when you need to bake in custom agents:

```bash
# Build with your local ~/.claude/agents
bin/claude-sandbox build

# Push manually (if needed) - replace 'yourusername' with your Docker Hub username
docker tag claude-sandbox:latest yourusername/claude-sandbox:latest
docker push yourusername/claude-sandbox:latest
```

**Note**: CI builds use minimal/empty agent configuration. Local builds via `bin/claude-sandbox build` copy your `~/.claude/agents`, `~/.claude/artifacts`, and `~/.claude/commands` into the image.

## Global Installation

To use claude-sandbox from any directory:

### Option 1: Add to PATH

```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="$HOME/.claude/claude-sandbox/bin:$PATH"
```

### Option 2: Symlink to Local Bin

```bash
ln -s ~/.claude/claude-sandbox/bin/claude-sandbox ~/.local/bin/claude-sandbox
# Ensure ~/.local/bin is in PATH
```

### Auto-Detection

When called from within a git repository, claude-sandbox will automatically detect:
- REPO_URL: From git remote get-url origin
- REPO_BRANCH: From git branch --show-current

These can still be overridden with environment variables.

Example:
```bash
cd ~/projects/my-app
# No need to set REPO_URL or REPO_BRANCH
claude-sandbox local "fix the login bug"
```

Override auto-detection:
```bash
REPO_URL="https://github.com/other/repo.git" \
REPO_BRANCH="develop" \
claude-sandbox local "work on feature X"
```

## Environment Variables

### Required

| Variable | Description |
|----------|-------------|
| `GITHUB_TOKEN` | GitHub personal access token with `repo` scope |
| `CLAUDE_CODE_OAUTH_TOKEN` or `ANTHROPIC_API_KEY` | **Choose one:** OAuth token from `claude setup-token` (uses subscription) OR API key (pay-as-you-go) |
| `REPO_URL` | Repository URL - **auto-detected** from `git remote get-url origin` when using `bin/claude-sandbox` commands |

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `ANTHROPIC_API_KEY` | - | Alternative to OAuth token (pay-as-you-go API) |
| `REPO_BRANCH` | Auto-detected or `main` | Branch to clone (auto-detected from `git branch --show-current`) |
| `DATABASE_NAME` | `sandbox_development` | PostgreSQL database name |
| `TELEGRAM_BOT_TOKEN` | - | Telegram bot token for notifications |
| `TELEGRAM_CHAT_ID` | - | Telegram chat ID to receive notifications |
| `CLAUDE_IMAGE` | Auto-detected from git remote or `landovsky/claude-sandbox:latest` | Docker image for remote runs (auto-detects `owner/claude-sandbox:latest` from repository context) |
| `CLAUDE_REGISTRY` | - | Registry for pushing images |

### Getting OAuth Token

```bash
# Run once, token valid for 1 year
claude setup-token

# Complete browser login
# Save the sk-ant-oat01-... token securely
```

## Image Naming for Forks

Docker image names automatically adapt to your fork:

**GitHub Actions (CI/CD):**
- Uses `${{ github.repository_owner }}/claude-sandbox:version`
- If you fork `landovsky/claude-golem` to `yourname/claude-golem`
- Images push to `yourname/claude-sandbox:latest`

**Local/K8s Scripts:**
- Auto-detect owner from `git remote get-url origin`
- Constructs `owner/claude-sandbox:latest`
- Falls back to `landovsky/claude-sandbox:latest` if detection fails

**Override:**
```bash
export CLAUDE_IMAGE="myorg/custom-image:v2"
```

**Required Setup for Forks:**
1. Configure GitHub secrets: `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`
2. Ensure your Docker Hub account has a repository named `claude-sandbox`
3. No code changes needed!

## Commands

```bash
bin/claude-sandbox local <task>    # Run locally with Docker Compose
bin/claude-sandbox remote <task>   # Run on k8s cluster
bin/claude-sandbox build           # Build the Docker image
bin/claude-sandbox push            # Push image to registry
bin/claude-sandbox logs            # Follow logs of running k8s job
bin/claude-sandbox clean           # Clean up completed k8s jobs
```

## Workflow Agents

The build process (`bin/claude-sandbox build`) bakes your workflow agents into the image:

```
~/.claude/agents/       → /home/claude/.claude/agents/
~/.claude/artifacts/    → /home/claude/.claude/artifacts/
~/.claude/commands/    → /home/claude/.claude/commands/
```

This means:
- Agents are versioned with each image build
- No runtime dependencies on host filesystem
- Works identically locally and on k8s
- **Rebuild the image when you update agents**

## What's Included

The sandbox container includes (Rails-optimized stack):
- Ruby (3.2, 3.3, or 3.4 - auto-detected from project)
- Node.js 22 LTS
- PostgreSQL 16 client (with PostGIS support)
- Redis 7 client
- Google Chrome (for Capybara system tests)
- beads (`bd`) for task tracking
- Claude Code CLI
- SOPS + age for encrypted secrets management

### Dynamic Service Composition

The sandbox automatically detects which services your project needs and only starts those services. This works for **both local (Docker Compose) and remote (Kubernetes) execution**.

**Detection logic:**
- Scans `Gemfile` for gems like `pg`, `redis`, `sidekiq`
- Scans `package.json` for packages like `pg`, `redis`, `bull`, `bullmq`
- Only starts PostgreSQL if postgres client is detected
- Only starts Redis if redis client or job queue library is detected

**How it works:**

*Local (Docker Compose):*
1. Pre-launch detection runs before `docker compose up`
2. Analyzes repository files (local or via `git archive`)
3. Builds appropriate `--profile` flags for Docker Compose
4. Only required services are started

*Remote (Kubernetes):*
1. Pre-launch detection runs before job creation
2. Analyzes repository files (same detection script as local)
3. Generates job YAML with only required sidecar containers
4. Conditionally includes DATABASE_URL/REDIS_URL env vars

**Fallback behavior:**
- If detection fails or can't access repository files, starts all services (safe default)
- For GitHub.com HTTPS URLs, `git archive` is not supported - falls back to all services
- Local repositories and git servers that support `git archive` get accurate detection

**Benefits:**
- Faster startup when services aren't needed
- Lower resource usage (especially in K8s where each sidecar consumes cluster resources)
- Same environment guarantees (services are there when needed)

This happens automatically - no configuration required.

### S3-Backed Dependency Caching

The sandbox includes S3-backed caching for Ruby gems and Node packages to speed up subsequent runs. This is especially beneficial for Kubernetes deployments where each job starts with a fresh environment.

**How it works:**
1. Before installing dependencies, checks S3 for a cached version based on lockfile hash (sha256)
2. If cache hit, downloads and extracts the cached dependencies (typically 10-30s vs 2-5min install)
3. After successful install, uploads dependencies to S3 for future use
4. Works for both `bundle install` (Ruby gems) and `npm install` (Node packages)

**Configuration:**

Add AWS credentials and S3 bucket to your Kubernetes secret:

```bash
kubectl create secret generic claude-sandbox-secrets \
  --from-literal=AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE" \
  --from-literal=AWS_SECRET_ACCESS_KEY="wJalr..." \
  --from-literal=AWS_REGION="us-east-1" \
  --from-literal=CACHE_S3_BUCKET="my-claude-sandbox-cache" \
  # ... other secrets
```

Or in your local `.env.claude-sandbox`:

```bash
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalr...
AWS_REGION=us-east-1
CACHE_S3_BUCKET=my-claude-sandbox-cache
```

**Optional settings:**
- `CACHE_S3_PREFIX` - Key prefix for cache organization (default: `claude-sandbox-cache`)
- `CACHE_COMPRESSION` - Enable gzip compression for cache archives (default: `true`)
- `CACHE_VERBOSE` - Enable verbose cache logging (default: `false`)

**Cache keys:**
- Ruby gems: `s3://bucket/prefix/bundle-{lockfile-hash}.tar.gz`
- Node packages: `s3://bucket/prefix/npm-{lockfile-hash}.tar.gz`

**If caching is disabled** (missing credentials or bucket), dependency installation falls back to normal behavior with local-only caching.

**Extensibility:** The caching system is designed to be easily extended for other package managers (pip, cargo, etc.) - see `lib/cache-manager.sh` for implementation.

## Safety Features

### Protected Branches

The `safe-git` wrapper intercepts git commands and blocks:
- `git push --force origin main`
- `git push --force origin master`
- `git push --force origin production`

Direct pushes to protected branches trigger a warning but are allowed (your GitHub branch protection should be the final gate).

### Fresh Clone

Each run starts with a fresh `git clone`. Your local working directory is never touched. Claude works on its own copy.

### Telegram Notifications

When configured, you'll receive a message when:
- Claude completes the task (exit code 0)
- Claude fails (non-zero exit code)
- The session is interrupted (Ctrl+C or timeout)

### Environment Configuration

Project-specific environment variables can be managed two ways:

#### .env.claude-sandbox - Plaintext Config
For non-sensitive configuration (database names, feature flags, etc.):

```bash
# In your project root
cat > .env.claude-sandbox << EOF
DATABASE_NAME=myapp_development
RAILS_ENV=development
ENABLE_FEATURE_X=true
EOF

git add .env.claude-sandbox
git commit -m "Add project config"
```

**Safe to commit** - no encryption needed for public config.

#### .env.sops - Encrypted Secrets
For sensitive values (API keys, passwords, tokens):

```bash
# 1. Generate age key (one-time)
age-keygen -o age-key.txt

# 2. Store in k8s
kubectl create secret generic age-key --from-file=age-key.txt

# 3. In your project, create .sops.yaml
cat > .sops.yaml << EOF
creation_rules:
  - age: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p  # Your public key
EOF

# 4. Create encrypted secrets
sops .env.sops
# Add: STRIPE_SECRET_KEY=sk_test_xxx
# Save (auto-encrypts)

# 5. Commit and use
git add .sops.yaml .env.sops
git commit -m "Add encrypted secrets"
```

**You can use both!** Put public config in `.env.claude-sandbox` and secrets in `.env.sops`.

**See [docs/SOPS-setup.md](docs/SOPS-setup.md) for complete guide.**

## Directory Structure

```
claude-sandbox/
├── Dockerfile              # Dev environment image
├── docker-compose.yml      # Local orchestration
├── entrypoint.sh           # Clone, setup, run Claude
├── safe-git                # Git wrapper (force-push protection)
├── notify-telegram.sh      # Telegram notification script
├── README.md               # This file
├── bin/
│   └── claude-sandbox      # Main CLI script
├── docs/
│   ├── kubernetes-cluster-setup-guide.md  # K8s cluster configuration guide
│   ├── SOPS-setup.md                      # Encrypted secrets setup
│   ├── RUBY-VERSIONS-management.md                   # Ruby version management
│   ├── ENV-FILES-management.md                       # Environment file documentation
│   └── docker-gotchas.md                  # Docker troubleshooting
└── k8s/
    ├── job-template.yaml   # K8s Job template (reference)
    └── TESTING.md          # K8s testing procedures
```

## Workflow Integration

This sandbox is designed to work with the multi-agent workflow system:

1. **Master** receives task via `TASK` environment variable
2. Claude assesses and either fast-tracks or delegates to Analyst → Planner → Implementer → Reviewer
3. Work happens on feature branches (Claude decides naming)
4. On completion, creates PR to main (if configured)
5. Telegram notification sent

## Customization

### Ruby Version Management

The sandbox automatically detects the Ruby version from your project's `.ruby-version` file and uses the appropriate Docker image.

**Supported versions:**
- Ruby 3.2 (3.2.6)
- Ruby 3.3 (3.3.6)
- Ruby 3.4 (3.4.7)

**Automatic detection:**
1. The launcher checks for `.ruby-version` in your repository
2. Extracts the major.minor version (e.g., `3.3.1` → `3.3`)
3. Selects the matching image tag: `claude-sandbox:ruby-3.3`
4. If no `.ruby-version` exists, uses the default (Ruby 3.4)

**Manual override:**
```bash
# Force a specific Ruby version
export IMAGE_TAG=ruby-3.2
bin/claude-sandbox local "work on task 123"
```

**Adding new Ruby versions:**
1. Edit `ruby-versions.yaml` to add the new version
2. Rebuild images: `bin/claude-sandbox build`
3. All versions are built automatically with tags like `ruby-X.Y`

See [docs/RUBY-VERSIONS-management.md](docs/RUBY-VERSIONS-management.md) for details.

### Add System Dependencies

Edit `Dockerfile`, add to the `apt-get install` line.

### Modify Protected Branches

Edit `docker/claude-sandbox/safe-git`:
```bash
PROTECTED_BRANCHES="main master production staging"  # Add branches here
```

## Troubleshooting

### "Permission denied" on bin/claude-sandbox

```bash
chmod +x bin/claude-sandbox
```

### Chrome crashes with "session deleted"

The container needs shared memory. For local runs, `shm_size: 2gb` is set in docker-compose.yml. For k8s, an emptyDir volume is mounted at `/dev/shm`.

### "Cannot connect to database"

Ensure postgres and redis services are healthy before claude starts. The compose file has health checks configured.

### Telegram not working

1. Check bot token is correct (from @BotFather)
2. Check chat ID (use @userinfobot to get yours)
3. For groups, chat ID should be negative (e.g., `-1001234567890`)
4. Ensure the bot is a member of the group/channel

## Security Notes

- The container runs as non-root user `claude`
- GitHub token is only used for git operations (clone/push)
- No secrets are persisted - container is ephemeral
- Consider using GitHub fine-grained tokens with minimal scope
