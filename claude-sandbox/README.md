# Claude Sandbox

Run Claude Code autonomously in an isolated Docker environment with full permissions (`--dangerously-skip-permissions`).

## Why?

When you want Claude to work on tasks without supervision:
- **Isolation**: Fresh git clone, doesn't touch your local checkout
- **Safety**: Protected branches (main/master/production) can't be force-pushed
- **Notifications**: Get Telegram alerts when Claude finishes or gets stuck
- **Reproducibility**: Same environment locally and remotely
- **Full stack**: PostgreSQL, Redis, Chrome (for system tests) included
- **SOPS Integration**: Encrypted secrets in your repo, no manual k8s secret management

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

> ⚠️ **WIP - Remote execution with services (Postgres/Redis) is under development**
>
> **Working:**
> - ✅ Basic job execution (clone repo, run Claude, no database)
> - ✅ SOPS encrypted secrets
> - ✅ .env.claude plaintext config
> - ✅ REPO_URL auto-detection
> - ✅ Parallel deployments
>
> **Pending:**
> - ⏳ Database readiness checks in entrypoint.sh
> - ⏳ Redis readiness checks in entrypoint.sh
> - ⏳ Fix hardcoded database name in k8s template
> - ⏳ Test with Postgres/Redis sidecars enabled
> - ⏳ Update production job-template.yaml with all fixes
>
> See [k8s/TESTING.md](k8s/TESTING.md) for current testing status.

```bash
# First, create secrets in your cluster
# Note: REPO_URL is optional in secret if using auto-detection
kubectl create secret generic claude-sandbox-secrets \
  --from-literal=GITHUB_TOKEN="$GITHUB_TOKEN" \
  --from-literal=CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN" \
  --from-literal=TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN" \
  --from-literal=TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"

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

The sandbox container includes:
- Ruby 3.4.x (matches project)
- Node.js 20 LTS
- PostgreSQL 16 client
- Redis 7 client
- Google Chrome (for Capybara system tests)
- beads (`bd`) for task tracking
- Claude Code CLI
- SOPS + age for encrypted secrets management

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

#### .env.claude - Plaintext Config
For non-sensitive configuration (database names, feature flags, etc.):

```bash
# In your project root
cat > .env.claude << EOF
DATABASE_NAME=myapp_development
RAILS_ENV=development
ENABLE_FEATURE_X=true
EOF

git add .env.claude
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

**You can use both!** Put public config in `.env.claude` and secrets in `.env.sops`.

**See [docs/SOPS-SETUP.md](docs/SOPS-SETUP.md) for complete guide.**

## Directory Structure

```
docker/claude-sandbox/
├── Dockerfile              # Dev environment image
├── docker-compose.yml      # Local orchestration
├── entrypoint.sh           # Clone, setup, run Claude
├── safe-git                # Git wrapper (force-push protection)
├── notify-telegram.sh      # Telegram notification script
├── README.md               # This file
└── k8s/
    ├── job-template.yaml   # K8s Job template
    └── secrets.yaml.example # Secrets template
```

## Workflow Integration

This sandbox is designed to work with the multi-agent workflow system:

1. **Master** receives task via `TASK` environment variable
2. Claude assesses and either fast-tracks or delegates to Analyst → Planner → Implementer → Reviewer
3. Work happens on feature branches (Claude decides naming)
4. On completion, creates PR to main (if configured)
5. Telegram notification sent

## Customization

### Change Ruby Version

Edit `docker-compose.yml`:
```yaml
build:
  args:
    RUBY_VERSION: "3.3.0"  # Change this
```

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
