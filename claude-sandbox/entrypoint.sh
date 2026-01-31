#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[sandbox]${NC} $1"; }
info() { echo -e "${BLUE}[sandbox]${NC} $1"; }
action() { echo -e "${CYAN}[sandbox]${NC} $1"; }
success() { echo -e "${GREEN}[sandbox]${NC} ✓ $1"; }
warn() { echo -e "${YELLOW}[sandbox]${NC} $1"; }
error() { echo -e "${RED}[sandbox]${NC} $1"; }
section() { echo -e "\n${BOLD}${BLUE}▶ $1${NC}"; }
separator() { echo -e "${DIM}────────────────────────────────────────${NC}"; }

# Notification on exit (success, failure, or interrupt)
EXIT_CODE=0
cleanup() {
  EXIT_CODE=$?
  echo ""
  separator
  if [ $EXIT_CODE -eq 0 ]; then
    success "Session completed successfully"
  else
    error "Session ended with exit code: $EXIT_CODE"
  fi
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

section "Repository Setup"
# Clone fresh or update existing
# QUICK FIX: When using workspace volume (local testing), this reuses existing workspace
# TODO: Always clone fresh for production/k8s runs
if [ ! -d ".git" ]; then
  action "Cloning repository..."
  # Insert token into URL for authentication
  AUTH_URL=$(echo "$REPO_URL" | sed "s|https://|https://x-access-token:${GITHUB_TOKEN}@|")

  # Clone to temp dir (git won't clone to non-empty dir, and node_modules volume makes it non-empty)
  CLONE_DIR=$(mktemp -d)
  git clone --branch "${REPO_BRANCH:-main}" "$AUTH_URL" "$CLONE_DIR"

  # Move contents to workspace (preserving node_modules volume)
  action "Moving repository to workspace..."
  # First clear any leftover files (except volume mounts)
  find . -maxdepth 1 ! -name '.' ! -name '..' ! -name 'node_modules' -exec rm -rf {} + 2>/dev/null || true
  # Move repo contents
  shopt -s dotglob  # Include hidden files
  mv "$CLONE_DIR"/* . 2>/dev/null || true
  rmdir "$CLONE_DIR"
else
  action "Updating existing repository..."
  git fetch origin
  git checkout "${REPO_BRANCH:-main}"
  git reset --hard "origin/${REPO_BRANCH:-main}"
fi

# Show current state
info "Repository: $REPO_URL"
info "Branch: $(git branch --show-current)"
info "Commit: $(git rev-parse --short HEAD)"
separator

section "Project Detection"

# Detect Ruby/Rails project
HAS_RUBY=false
HAS_RAILS=false
if [ -f "Gemfile" ]; then
  HAS_RUBY=true
  success "Ruby project detected"

  # Check if it's a Rails project
  if grep -q "gem ['\"]rails['\"]" Gemfile 2>/dev/null || [ -f "config/application.rb" ]; then
    HAS_RAILS=true
    success "Rails framework detected"
  fi
fi

# Detect Node.js project
HAS_NODE=false
if [ -f "package.json" ]; then
  HAS_NODE=true
  success "Node.js project detected"
fi

# If no project files detected, log it
if [ "$HAS_RUBY" = false ] && [ "$HAS_NODE" = false ]; then
  info "Generic project (no Ruby or Node.js detected)"
fi
separator

section "Dependency Installation"

# Install Ruby dependencies if needed
GEMS_NEED_INSTALL=false
if [ "$HAS_RUBY" = true ]; then
  GEMFILE_CHECKSUM=$(md5sum Gemfile.lock 2>/dev/null | cut -d' ' -f1)
  # Check both: checksum matches AND gems are actually available
  if [ ! -f ".bundle/.installed" ] || [ "$(cat .bundle/.installed 2>/dev/null)" != "$GEMFILE_CHECKSUM" ] || ! bundle exec ruby -e "exit 0" 2>/dev/null; then
    action "Installing Ruby gems..."
    bundle config set --local path 'vendor/bundle'
    bundle config set --local without 'production'
    bundle install --jobs 4
    GEMS_NEED_INSTALL=true
    success "Ruby gems installed"
  else
    info "Ruby gems up to date (using cached)"
  fi
fi

# Install Node dependencies if needed
PACKAGES_NEED_INSTALL=false
if [ "$HAS_NODE" = true ]; then
  # Ensure node_modules exists with correct ownership
  mkdir -p node_modules

  PACKAGE_CHECKSUM=$(md5sum package-lock.json 2>/dev/null | cut -d' ' -f1)
  if [ ! -f "node_modules/.installed" ] || [ "$(cat node_modules/.installed 2>/dev/null)" != "$PACKAGE_CHECKSUM" ]; then
    action "Installing Node packages..."
    npm install
    PACKAGES_NEED_INSTALL=true
    success "Node packages installed"
  else
    info "Node packages up to date (using cached)"
  fi
fi

# Mark dependencies as successfully installed
if [ "$GEMS_NEED_INSTALL" = true ]; then
  echo "$GEMFILE_CHECKSUM" > .bundle/.installed
fi
if [ "$PACKAGES_NEED_INSTALL" = true ] && [ -n "$PACKAGE_CHECKSUM" ]; then
  echo "$PACKAGE_CHECKSUM" > node_modules/.installed
fi

if [ "$HAS_RUBY" = false ] && [ "$HAS_NODE" = false ]; then
  info "No dependencies to install"
fi
separator

# Prepare Rails database if this is a Rails project
if [ "$HAS_RAILS" = true ]; then
  section "Database Setup"
  action "Preparing Rails database..."
  bundle exec rails db:prepare || bundle exec rails db:setup
  success "Database ready"
  separator
fi

# Configure Claude to skip onboarding (required for OAuth token to work)
mkdir -p /home/claude/.claude
echo '{"hasCompletedOnboarding": true}' > /home/claude/.claude.json

cd /workspace

section "Beads setup..."
info "Initializing bead database..."

# Setup config with # no-db: false
mkdir -p .beads
cat > .beads/config.yaml << 'EOF'
no-db: true
EOF

bd --import-only --rename-on-import sync
success "Beads initialized"

# Prime Claude
bd setup claude
success "Claude setup complete"
separator

section "Claude Code Session"
info "Task: $TASK"
separator

# Execute Claude with full permissions and live streaming output
# bash
exec claude --dangerously-skip-permissions -p "$TASK" \
  --output-format stream-json \
  --verbose \
  --include-partial-messages | \
  jq -rj 'select(.type == "stream_event" and .event.delta.type? == "text_delta") | .event.delta.text'