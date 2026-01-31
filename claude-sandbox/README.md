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

### Local (Docker Compose)

```bash
# Get OAuth token (one-time setup, valid 1 year)
claude setup-token
# Complete browser login, save the sk-ant-oat01-... token

# Set required environment variables
export GITHUB_TOKEN="ghp_..."
export CLAUDE_CODE_OAUTH_TOKEN="sk-ant-oat01-..."  # From setup-token
export REPO_URL="https://github.com/you/your-repo.git"

# Optional: Telegram notifications
export TELEGRAM_BOT_TOKEN="123456789:ABC..."
export TELEGRAM_CHAT_ID="-100..."

# Run Claude on a task
bin/claude-sandbox local "fix the authentication bug in login controller"
```

### Remote (Kubernetes/k3s)

```bash
# First, create secrets in your cluster
kubectl create secret generic claude-sandbox-secrets \
  --from-literal=GITHUB_TOKEN="$GITHUB_TOKEN" \
  --from-literal=ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  --from-literal=REPO_URL="$REPO_URL" \
  --from-literal=TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN" \
  --from-literal=TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"

# Build and push image
bin/claude-sandbox build
export CLAUDE_REGISTRY="ghcr.io/yourusername"
bin/claude-sandbox push

# Run remotely
export CLAUDE_IMAGE="$CLAUDE_REGISTRY/claude-sandbox:latest"
bin/claude-sandbox remote "implement user profile page"

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
| `CLAUDE_CODE_OAUTH_TOKEN` | OAuth token from `claude setup-token` (valid 1 year, uses your Claude subscription) |
| `REPO_URL` | Repository URL (auto-detected from `git remote get-url origin`) |

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

### SOPS Encrypted Secrets

Project-specific environment variables can be managed with SOPS:

**Benefits:**
- Secrets live in your repo (encrypted, safe to commit)
- Version-controlled with your code
- No manual k8s secret management per project
- Works locally and in k8s

**Quick setup:**

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
# Add: DATABASE_NAME=myapp_dev
# Save (auto-encrypts)

# 5. Commit and use
git add .sops.yaml .env.sops
git commit -m "Add encrypted config"
```

When the job runs, `.env.sops` is automatically decrypted and loaded.

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
