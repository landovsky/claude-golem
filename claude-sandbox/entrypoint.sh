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

log() { echo -e "${GREEN}[sandbox]${NC} $1\n"; }
info() { echo -e "${BLUE}[sandbox]${NC} $1\n"; }
action() { echo -e "${CYAN}[sandbox]${NC} $1\n"; }
success() { echo -e "${GREEN}[sandbox]${NC} ✓ $1\n"; }
warn() { echo -e "${YELLOW}[sandbox]${NC} $1\n"; }
error() { echo -e "${RED}[sandbox]${NC} $1\n"; }
section() { echo -e "\n${BOLD}${BLUE}▶ $1${NC}"; }
separator() { echo -e "${DIM}────────────────────────────────────────${NC}"; }

# Load cache manager
if [ -f /usr/local/lib/cache-manager.sh ]; then
  source /usr/local/lib/cache-manager.sh
fi

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

if [ -z "${TASK:-}" ] && [ "${INTERACTIVE:-}" != "true" ]; then
  error "TASK is required (or set INTERACTIVE=true)"
  exit 1
fi

cd /workspace

# Fix git ownership issues in container
git config --global --add safe.directory /workspace

section "Repository Setup"
# Clone fresh or update existing
# Check if existing repo matches REPO_URL (workspace volume may have a different repo)
AUTH_URL=$(echo "$REPO_URL" | sed "s|https://|https://x-access-token:${GITHUB_TOKEN}@|")
if [ -d ".git" ]; then
  CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
  # Compare repos ignoring auth tokens and .git suffix
  CURRENT_REPO=$(echo "$CURRENT_REMOTE" | sed 's|https://[^@]*@|https://|; s|\.git$||')
  EXPECTED_REPO=$(echo "$REPO_URL" | sed 's|\.git$||')
  if [ "$CURRENT_REPO" != "$EXPECTED_REPO" ]; then
    warn "Workspace has different repo ($CURRENT_REPO)"
    action "Clearing workspace for new repo..."
    find . -maxdepth 1 ! -name '.' ! -name '..' ! -name 'node_modules' -exec rm -rf {} + 2>/dev/null || true
  fi
fi

if [ ! -d ".git" ]; then
  action "Cloning repository..."

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

  # Check for uncommitted changes
  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    warn "Repository has uncommitted changes - stashing for sandbox"
    echo ""

    # Show what will be stashed
    git status --short
    echo ""

    # Create descriptive stash message with timestamp
    STASH_MSG="sandbox-auto-stash-$(date +%Y%m%d-%H%M%S)"

    # Check if only beads files are dirty
    DIRTY_FILES=$(git diff --name-only HEAD)
    if echo "$DIRTY_FILES" | grep -qv "^\.beads/"; then
      # Non-beads files are dirty
      warn "Stashing changes (including non-beads files)"
      info "Your work in non-beads files will be preserved in git stash"
    else
      # Only beads files are dirty
      info "Stashing beads changes (sandbox uses clean remote state)"
    fi

    # Stash all changes
    if git stash push -u -m "$STASH_MSG" >/dev/null 2>&1; then
      success "Changes stashed as: $STASH_MSG"
      info "Retrieve later with: git stash list; git stash pop"
    else
      # Stash failed, force clean
      warn "Stash failed - forcing clean state"
      git reset --hard HEAD >/dev/null 2>&1
      git clean -fd >/dev/null 2>&1
    fi

    echo ""
  fi

  # Ensure remote URL is correct (may have changed between runs)
  git remote set-url origin "$AUTH_URL"

  # Proceed with safe update
  git fetch origin
  # Clean .beads/ before checkout - it gets recreated from sync branch later
  # and leftover files from previous runs cause checkout conflicts
  rm -rf .beads/
  # Use -B to create/reset local branch from remote (handles branches that only exist on remote)
  git checkout -B "${REPO_BRANCH:-main}" "origin/${REPO_BRANCH:-main}"
fi

# Show current state
info "Repository: $REPO_URL"
info "Branch: $(git branch --show-current)"
info "Commit: $(git rev-parse --short HEAD)"
separator

section "Environment Configuration"

# Load plaintext environment variables from .env.claude-sandbox if present
if [ -f .env.claude-sandbox ]; then
  action "Loading .env.claude-sandbox..."
  set -a  # Automatically export all variables
  source .env.claude-sandbox
  set +a  # Turn off auto-export
  success "Environment variables loaded from .env.claude-sandbox"
else
  info "No .env.claude-sandbox file found"
fi

# Load encrypted secrets from .env.sops if present
if [ -f .env.sops ]; then
  if [ -f /secrets/age-key.txt ]; then
    action "Decrypting .env.sops with age key..."
    export SOPS_AGE_KEY_FILE=/secrets/age-key.txt

    # Decrypt and export environment variables
    eval "$(sops -d --output-type dotenv .env.sops | sed 's/^/export /')"

    success "Encrypted secrets loaded from .env.sops"
  else
    warn ".env.sops found but age key not available at /secrets/age-key.txt"
    warn "Skipping SOPS decryption"
  fi
else
  info "No .env.sops file found"
fi

# Summary
if [ ! -f .env.claude-sandbox ] && [ ! -f .env.sops ]; then
  info "Using environment variables from k8s secrets only"
fi
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

section "Service Detection"

# Initialize all flags to false
NEEDS_POSTGRES=false
NEEDS_MYSQL=false
NEEDS_SQLITE=false
NEEDS_REDIS=false

# Detect Postgres
if [ -f "Gemfile" ] && grep -q "gem ['\"]pg['\"][,[:space:]]" Gemfile 2>/dev/null; then
  NEEDS_POSTGRES=true
fi
if [ -f "package.json" ] && grep -q "\"pg\"" package.json 2>/dev/null; then
  NEEDS_POSTGRES=true
fi

# Detect MySQL
if [ -f "Gemfile" ] && grep -q "gem ['\"]mysql2['\"][,[:space:]]" Gemfile 2>/dev/null; then
  NEEDS_MYSQL=true
fi
if [ -f "package.json" ] && grep -q "\"mysql2\"" package.json 2>/dev/null; then
  NEEDS_MYSQL=true
fi

# Detect SQLite
if [ -f "Gemfile" ] && grep -q "gem ['\"]sqlite3['\"][,[:space:]]" Gemfile 2>/dev/null; then
  NEEDS_SQLITE=true
fi
if [ -f "package.json" ] && grep -q "\"sqlite3\"" package.json 2>/dev/null; then
  NEEDS_SQLITE=true
fi

# Detect Redis - check for redis gem/package or job queue libraries
if [ -f "Gemfile" ] && (grep -q "gem ['\"]redis['\"][,[:space:]]" Gemfile 2>/dev/null || \
                         grep -q "gem ['\"]sidekiq['\"][,[:space:]]" Gemfile 2>/dev/null); then
  NEEDS_REDIS=true
fi
if [ -f "package.json" ] && (grep -q "\"redis\"" package.json 2>/dev/null || \
                             grep -q "\"bull\"" package.json 2>/dev/null || \
                             grep -q "\"bullmq\"" package.json 2>/dev/null); then
  NEEDS_REDIS=true
fi

# Log detected services
if [ "$NEEDS_POSTGRES" = true ]; then
  success "PostgreSQL requirement detected"
fi
if [ "$NEEDS_MYSQL" = true ]; then
  success "MySQL requirement detected"
fi
if [ "$NEEDS_SQLITE" = true ]; then
  success "SQLite requirement detected"
fi
if [ "$NEEDS_REDIS" = true ]; then
  success "Redis requirement detected"
fi

# Log if no services detected
if [ "$NEEDS_POSTGRES" = false ] && \
   [ "$NEEDS_MYSQL" = false ] && \
   [ "$NEEDS_SQLITE" = false ] && \
   [ "$NEEDS_REDIS" = false ]; then
  info "No external services required"
fi

# Export for use by child processes or external scripts
export NEEDS_POSTGRES
export NEEDS_MYSQL
export NEEDS_SQLITE
export NEEDS_REDIS
separator

section "Service Readiness Checks"

# Wait for PostgreSQL if needed
if [ "$NEEDS_POSTGRES" = true ]; then
  # Check if DATABASE_URL is set (indicates sidecar/external service)
  if [ -n "$DATABASE_URL" ]; then
    action "Waiting for PostgreSQL to be ready..."

    # Extract connection details from DATABASE_URL
    POSTGRES_HOST=$(echo "$DATABASE_URL" | sed -E 's|.*@([^:/]+).*|\1|')
    POSTGRES_PORT=$(echo "$DATABASE_URL" | sed -E 's|.*:([0-9]+)/.*|\1|')
    POSTGRES_USER=$(echo "$DATABASE_URL" | sed -E 's|.*://([^:]+):.*|\1|')
    POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
    POSTGRES_PORT="${POSTGRES_PORT:-5432}"
    POSTGRES_USER="${POSTGRES_USER:-claude}"

    MAX_RETRIES=30
    RETRY_COUNT=0

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
      if pg_isready -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" > /dev/null 2>&1; then
        success "PostgreSQL is ready"
        break
      fi

      RETRY_COUNT=$((RETRY_COUNT + 1))
      if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        error "PostgreSQL failed to become ready after ${MAX_RETRIES} attempts"
        exit 1
      fi

      sleep 1
    done
  else
    info "PostgreSQL detected but DATABASE_URL not set (using external/preconfigured database)"
  fi
fi

# Wait for Redis if needed
if [ "$NEEDS_REDIS" = true ]; then
  # Check if REDIS_URL is set (indicates sidecar/external service)
  if [ -n "$REDIS_URL" ]; then
    action "Waiting for Redis to be ready..."

    REDIS_HOST=$(echo "$REDIS_URL" | sed -E 's|.*://([^:/]+).*|\1|')
    REDIS_PORT=$(echo "$REDIS_URL" | sed -E 's|.*:([0-9]+).*|\1|')
    REDIS_HOST="${REDIS_HOST:-localhost}"
    REDIS_PORT="${REDIS_PORT:-6379}"

    MAX_RETRIES=30
    RETRY_COUNT=0

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
      if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping > /dev/null 2>&1; then
        success "Redis is ready"
        break
      fi

      RETRY_COUNT=$((RETRY_COUNT + 1))
      if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        error "Redis failed to become ready after ${MAX_RETRIES} attempts"
        exit 1
      fi

      sleep 1
    done
  else
    info "Redis detected but REDIS_URL not set (using external/preconfigured service)"
  fi
fi

# MySQL readiness check
if [ "$NEEDS_MYSQL" = true ]; then
  # Check if MYSQL_URL or similar is set
  if [ -n "$MYSQL_URL" ] || [ -n "$DATABASE_URL" ]; then
    action "Waiting for MySQL to be ready..."

    MYSQL_HOST="localhost"
    MYSQL_PORT="3306"

    MAX_RETRIES=30
    RETRY_COUNT=0

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
      if mysqladmin ping -h "$MYSQL_HOST" -P "$MYSQL_PORT" --silent > /dev/null 2>&1; then
        success "MySQL is ready"
        break
      fi

      RETRY_COUNT=$((RETRY_COUNT + 1))
      if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        error "MySQL failed to become ready after ${MAX_RETRIES} attempts"
        exit 1
      fi

      sleep 1
    done
  else
    info "MySQL detected but no connection URL set (using external/preconfigured database)"
  fi
fi

# SQLite needs no readiness check (local file)
if [ "$NEEDS_SQLITE" = true ]; then
  info "SQLite detected (no readiness check needed)"
fi

# Log if no services need readiness checks
if [ "$NEEDS_POSTGRES" = false ] && \
   [ "$NEEDS_MYSQL" = false ] && \
   [ "$NEEDS_REDIS" = false ]; then
  info "No service readiness checks required"
fi
separator

section "Dependency Installation"

# Show cache status (#3)
if cache_is_enabled; then
  info "S3 cache enabled: s3://${CACHE_S3_BUCKET}/ (endpoint: ${AWS_ENDPOINT_URL:-aws})"
else
  info "S3 cache disabled (credentials not configured)"
fi

# Install Ruby dependencies if needed
GEMS_NEED_INSTALL=false
if [ "$HAS_RUBY" = true ]; then
  # Check lockfile exists (#2)
  if [ ! -f "Gemfile.lock" ]; then
    warn "Gemfile.lock not found - first run will be slower"
    info "Run 'bundle lock' locally to generate Gemfile.lock for caching"
  fi

  # Try to restore from S3 cache first
  CACHE_RESTORED=false
  if cache_restore "bundle" "Gemfile.lock" "vendor/bundle"; then
    success "Ruby gems restored from S3 cache"
    CACHE_RESTORED=true
  else
    if cache_is_enabled && [ -f "Gemfile.lock" ]; then
      info "Cache miss for Ruby gems - will install fresh"
    fi
  fi

  # Verify cache or install if needed
  GEMFILE_CHECKSUM=$(sha256sum Gemfile.lock 2>/dev/null | cut -d' ' -f1)
  # Check both: checksum matches AND gems are actually available
  if [ ! -f ".bundle/.installed" ] || [ "$(cat .bundle/.installed 2>/dev/null)" != "$GEMFILE_CHECKSUM" ] || ! bundle exec ruby -e "exit 0" 2>/dev/null; then
    action "Installing Ruby gems..."
    bundle config set --local path 'vendor/bundle'
    bundle config set --local without 'production'
    if ! bundle install --jobs 4; then
      error "bundle install failed"
      error "Check Gemfile and Gemfile.lock for issues"
      exit 1
    fi
    GEMS_NEED_INSTALL=true
    success "Ruby gems installed"

    # Save to S3 cache in background (don't block entrypoint)
    ( cache_save "bundle" "Gemfile.lock" "vendor/bundle" && \
      echo -e "${GREEN}[sandbox]${NC} ✓ Ruby gems cached to S3 (background)\n" || true ) &
  else
    if [ "$CACHE_RESTORED" = false ]; then
      info "Ruby gems up to date (using local cache)"
    fi
  fi
fi

# Install Node dependencies if needed
PACKAGES_NEED_INSTALL=false
if [ "$HAS_NODE" = true ]; then
  # Ensure node_modules exists with correct ownership
  mkdir -p node_modules

  # Check lockfile exists (#2)
  if [ ! -f "package-lock.json" ]; then
    warn "package-lock.json not found - first run will be slower"
    info "Run 'npm install' locally to generate package-lock.json for caching"
  fi

  # Try to restore from S3 cache first
  CACHE_RESTORED=false
  if cache_restore "npm" "package-lock.json" "node_modules"; then
    success "Node packages restored from S3 cache"
    CACHE_RESTORED=true
  else
    if cache_is_enabled && [ -f "package-lock.json" ]; then
      info "Cache miss for Node packages - will install fresh"
    fi
  fi

  # Verify cache or install if needed
  PACKAGE_CHECKSUM=$(sha256sum package-lock.json 2>/dev/null | cut -d' ' -f1)
  if [ ! -f "node_modules/.installed" ] || [ "$(cat node_modules/.installed 2>/dev/null)" != "$PACKAGE_CHECKSUM" ]; then
    action "Installing Node packages..."
    if ! npm install; then
      error "npm install failed"
      error "Check package.json and package-lock.json for issues"
      exit 1
    fi
    PACKAGES_NEED_INSTALL=true
    success "Node packages installed"

    # Save to S3 cache in background (don't block entrypoint)
    ( cache_save "npm" "package-lock.json" "node_modules" && \
      echo -e "${GREEN}[sandbox]${NC} ✓ Node packages cached to S3 (background)\n" || true ) &
  else
    if [ "$CACHE_RESTORED" = false ]; then
      info "Node packages up to date (using local cache)"
    fi
  fi
fi

# Mark dependencies as successfully installed (with full sha256)
if [ "$GEMS_NEED_INSTALL" = true ]; then
  mkdir -p .bundle
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
  bundle exec rails db:prepare 2>&1 || {
    warn "db:prepare failed, attempting db:reset..."
    bundle exec rails db:drop db:create db:migrate 2>&1 || warn "Database setup failed — Claude agent will need to handle this"
  }
  success "Database ready"
  separator
fi

# Configure Claude to skip onboarding (required for OAuth token to work)
mkdir -p /home/claude/.claude
echo '{"hasCompletedOnboarding": true}' > /home/claude/.claude.json

cd /workspace

section "Beads setup..."
info "Initializing bead database..."

mkdir -p .beads

# Step 1: Extract latest issues.jsonl from sync-branch if configured
if [ -f .beads/config.yaml ]; then
  SYNC_BRANCH=$(grep "^sync-branch:" .beads/config.yaml | sed 's/sync-branch:[[:space:]]*//; s/^"//; s/"$//' | tr -d '\r\n' | xargs)

  if [ -n "$SYNC_BRANCH" ]; then
    action "Extracting beads data from '$SYNC_BRANCH' branch..."

    if git show "origin/$SYNC_BRANCH:.beads/issues.jsonl" > .beads/issues.jsonl.tmp 2>/dev/null; then
      mv .beads/issues.jsonl.tmp .beads/issues.jsonl
      success "Extracted issues.jsonl from '$SYNC_BRANCH' branch"
    else
      # Try explicit fetch if not in tracking branches yet
      if git fetch origin "$SYNC_BRANCH" 2>/dev/null; then
        if git show "origin/$SYNC_BRANCH:.beads/issues.jsonl" > .beads/issues.jsonl.tmp 2>/dev/null; then
          mv .beads/issues.jsonl.tmp .beads/issues.jsonl
          success "Extracted issues.jsonl from '$SYNC_BRANCH' branch (after fetch)"
        else
          warn "Could not extract issues.jsonl from '$SYNC_BRANCH'"
        fi
      else
        warn "Could not fetch '$SYNC_BRANCH' branch"
      fi
    fi
  fi
fi

# Step 2: Clean slate - use JSONL-only mode (no database, no interactive prompts)
rm -f .beads/beads.db
grep -q "^no-db:" .beads/config.yaml 2>/dev/null || echo "no-db: true" >> .beads/config.yaml
success "Beads initialized (JSONL-only mode)"

# Step 4: Setup Claude integration (pipe 'n' to skip interactive prompts)
echo "n" | bd setup claude
success "Claude setup complete"
separator

section "Claude Code Session"

# Determine if hapi wrapping is enabled
CLAUDE_CMD="claude"
if [ -n "$HAPI_CLI_TOKEN" ]; then
  # Install hapi at runtime if not baked into image
  if ! command -v hapi &> /dev/null; then
    action "Installing hapi (not in image yet)..."
    npm install -g @twsxtd/hapi 2>&1 | tail -1
    success "Hapi installed"
  fi
  # Hapi reads CLI_API_TOKEN internally — map our env var to what it expects
  export CLI_API_TOKEN="$HAPI_CLI_TOKEN"
  # Default hub URL to host machine if not explicitly set
  export HAPI_API_URL="${HAPI_API_URL:-http://host.docker.internal:3006}"
  success "Hapi enabled (hub: $HAPI_API_URL)"
  info "Session will appear in your Hapi PWA"
  CLAUDE_CMD="hapi"
else
  info "Hapi disabled (set HAPI_CLI_TOKEN to enable)"
fi

if [ "${INTERACTIVE:-}" = "true" ] || [ "$CLAUDE_CMD" = "hapi" ]; then
  # Hapi sessions are always interactive — the phone/PWA is the interface
  if [ -n "${TASK:-}" ]; then
    info "Task: $TASK"
    info "Mode: interactive (hapi session)"
  else
    info "Interactive mode"
  fi
  separator

  # Build claude args — task as positional arg starts an interactive session
  # with the task as the first message (claude stays alive for hapi control)
  if [ -n "${TASK:-}" ]; then
    exec $CLAUDE_CMD --dangerously-skip-permissions "$TASK"
  else
    exec $CLAUDE_CMD --dangerously-skip-permissions
  fi
else
  info "Task: $TASK"
  separator

  # Execute Claude with full permissions and live streaming output
  exec claude --dangerously-skip-permissions -p "$TASK" \
    --output-format stream-json \
    --verbose \
    --include-partial-messages | \
    jq -rj 'select(.type == "stream_event" and .event.delta.type? == "text_delta") | .event.delta.text'
fi