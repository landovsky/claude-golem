#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[sandbox]${NC} $1"; }
warn() { echo -e "${YELLOW}[sandbox]${NC} $1"; }
error() { echo -e "${RED}[sandbox]${NC} $1"; }

# Notification on exit (success, failure, or interrupt)
EXIT_CODE=0
cleanup() {
  EXIT_CODE=$?
  log "Session ended with exit code: $EXIT_CODE"
  /usr/local/bin/notify-telegram.sh "$EXIT_CODE"
}
trap cleanup EXIT

# Validate required environment variables
if [ -z "$REPO_URL" ]; then
  error "REPO_URL is required"
  exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
  error "GITHUB_TOKEN is required"
  exit 1
fi

# Auth: Need either OAuth token or API key
if [ -z "$CLAUDE_CODE_OAUTH_TOKEN" ] && [ -z "$ANTHROPIC_API_KEY" ]; then
  error "Either CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY is required"
  error "Get OAuth token with: claude setup-token"
  exit 1
fi

if [ -z "$TASK" ]; then
  error "TASK is required"
  exit 1
fi

cd /workspace

# Clone fresh or update existing
# QUICK FIX: When using workspace volume (local testing), this reuses existing workspace
# TODO: Always clone fresh for production/k8s runs
if [ ! -d ".git" ]; then
  log "Cloning repository..."
  # Insert token into URL for authentication
  AUTH_URL=$(echo "$REPO_URL" | sed "s|https://|https://x-access-token:${GITHUB_TOKEN}@|")

  # Clone to temp dir (git won't clone to non-empty dir, and node_modules volume makes it non-empty)
  CLONE_DIR=$(mktemp -d)
  git clone --branch "${REPO_BRANCH:-main}" "$AUTH_URL" "$CLONE_DIR"

  # Move contents to workspace (preserving node_modules volume)
  log "Moving repository to workspace..."
  # First clear any leftover files (except volume mounts)
  find . -maxdepth 1 ! -name '.' ! -name '..' ! -name 'node_modules' -exec rm -rf {} + 2>/dev/null || true
  # Move repo contents
  shopt -s dotglob  # Include hidden files
  mv "$CLONE_DIR"/* . 2>/dev/null || true
  rmdir "$CLONE_DIR"
else
  log "Repository exists, fetching latest..."
  git fetch origin
  git checkout "${REPO_BRANCH:-main}"
  git reset --hard "origin/${REPO_BRANCH:-main}"
fi

# Show current state
log "Repository: $REPO_URL"
log "Branch: $(git branch --show-current)"
log "Commit: $(git rev-parse --short HEAD)"

# Detect project type and setup accordingly
log "Detecting project type..."

# Detect Ruby/Rails project
HAS_RUBY=false
HAS_RAILS=false
if [ -f "Gemfile" ]; then
  HAS_RUBY=true
  log "Detected Ruby project (Gemfile found)"

  # Check if it's a Rails project
  if grep -q "gem ['\"]rails['\"]" Gemfile 2>/dev/null || [ -f "config/application.rb" ]; then
    HAS_RAILS=true
    log "Detected Rails application"
  fi
fi

# Detect Node.js project
HAS_NODE=false
if [ -f "package.json" ]; then
  HAS_NODE=true
  log "Detected Node.js project (package.json found)"
fi

# If no project files detected, log it
if [ "$HAS_RUBY" = false ] && [ "$HAS_NODE" = false ]; then
  log "No Ruby or Node.js project detected, proceeding with generic setup"
fi

# Install Ruby dependencies if needed
GEMS_NEED_INSTALL=false
if [ "$HAS_RUBY" = true ]; then
  GEMFILE_CHECKSUM=$(md5sum Gemfile.lock 2>/dev/null | cut -d' ' -f1)
  # Check both: checksum matches AND gems are actually available
  if [ ! -f ".bundle/.installed" ] || [ "$(cat .bundle/.installed 2>/dev/null)" != "$GEMFILE_CHECKSUM" ] || ! bundle exec ruby -e "exit 0" 2>/dev/null; then
    log "Installing Ruby dependencies..."
    bundle config set --local path 'vendor/bundle'
    bundle config set --local without 'production'
    bundle install --jobs 4
    GEMS_NEED_INSTALL=true
  else
    log "Ruby dependencies already installed (checksum match)"
  fi
fi

# Install Node dependencies if needed
PACKAGES_NEED_INSTALL=false
if [ "$HAS_NODE" = true ]; then
  # Ensure node_modules exists with correct ownership
  mkdir -p node_modules

  PACKAGE_CHECKSUM=$(md5sum package-lock.json 2>/dev/null | cut -d' ' -f1)
  if [ ! -f "node_modules/.installed" ] || [ "$(cat node_modules/.installed 2>/dev/null)" != "$PACKAGE_CHECKSUM" ]; then
    log "Installing Node dependencies..."
    npm install
    PACKAGES_NEED_INSTALL=true
  else
    log "Node dependencies already installed (checksum match)"
  fi
fi

# Prepare Rails database if this is a Rails project
if [ "$HAS_RAILS" = true ]; then
  log "Preparing Rails database..."
  bundle exec rails db:prepare || bundle exec rails db:setup
fi

# Mark dependencies as successfully installed
if [ "$GEMS_NEED_INSTALL" = true ]; then
  echo "$GEMFILE_CHECKSUM" > .bundle/.installed
  log "Ruby dependencies cached for next run"
fi
if [ "$PACKAGES_NEED_INSTALL" = true ] && [ -n "$PACKAGE_CHECKSUM" ]; then
  echo "$PACKAGE_CHECKSUM" > node_modules/.installed
  log "Node dependencies cached for next run"
fi

# Copy workflow agents if they exist in the repo
if [ -d "artifacts" ]; then
  log "Workflow artifacts found"
fi

# Run Claude Code
log "Starting Claude Code session..."
log "Task: $TASK"
echo ""

# Configure Claude to skip onboarding (required for OAuth token to work)
mkdir -p /home/claude/.claude
echo '{"hasCompletedOnboarding": true}' > /home/claude/.claude.json

# Execute Claude with full permissions
exec claude --dangerously-skip-permissions -p "$TASK"
