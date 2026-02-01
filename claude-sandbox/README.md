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

# Build and push image (using public Docker Hub)
bin/claude-sandbox build
docker tag claude-sandbox:latest landovsky/claude-sandbox:latest
docker push landovsky/claude-sandbox:latest

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
| `CLAUDE_IMAGE` | `landovsky/claude-sandbox:latest` | Docker image for remote runs |
| `CLAUDE_REGISTRY` | - | Registry for pushing images |

### Getting OAuth Token

```bash
# Run once, token valid for 1 year
claude setup-token

# Complete browser login
# Save the sk-ant-oat01-... token securely
```

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

See [docs/RUBY-VERSIONS.md](docs/RUBY-VERSIONS.md) for details.

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
