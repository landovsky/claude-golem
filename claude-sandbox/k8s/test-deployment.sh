#!/bin/bash
# test-deployment.sh - Test claude-sandbox k8s deployment
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[test]${NC} $1"; }
warn() { echo -e "${YELLOW}[test]${NC} $1"; }
error() { echo -e "${RED}[test]${NC} $1"; }
info() { echo -e "${BLUE}[test]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOX_DIR="$(dirname "$SCRIPT_DIR")"

# Extract repository owner from git remote origin
# Handles both SSH (git@github.com:owner/repo.git) and HTTPS (https://github.com/owner/repo.git)
# Returns empty string for non-GitHub remotes (GitLab, Bitbucket, etc.)
get_repo_owner() {
  local git_dir="${1:-.}"
  local remote_url=$(git -C "$git_dir" remote get-url origin 2>/dev/null)
  if [ -z "$remote_url" ]; then
    echo ""
    return 1
  fi

  # Extract owner from both formats
  # SSH: git@github.com:owner/repo.git -> owner
  # HTTPS: https://github.com/owner/repo.git -> owner
  local owner=$(echo "$remote_url" | sed -E 's|^git@github\.com:([^/]+)/.*|\1|; s|^https://github\.com/([^/]+)/.*|\1|')

  # Validate: owner should be alphanumeric with dashes/underscores only
  # If URL didn't match GitHub patterns, sed passes it through unchanged
  # which would contain invalid chars like : / @
  if [[ "$owner" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "$owner"
  else
    # Non-GitHub remote or invalid format, return empty for fallback
    echo ""
    return 1
  fi
}

# Check prerequisites
check_prereqs() {
  log "Checking prerequisites..."

  if ! command -v kubectl &> /dev/null; then
    error "kubectl not found"
    exit 1
  fi

  if ! kubectl cluster-info &> /dev/null; then
    error "Cannot connect to k8s cluster"
    exit 1
  fi

  log "✓ kubectl and cluster access OK"
}

# Check secrets
check_secrets() {
  log "Checking secrets..."

  if ! kubectl get secret claude-sandbox-secrets &> /dev/null; then
    warn "Secret 'claude-sandbox-secrets' not found"
    echo ""
    echo "Create it with:"
    echo "kubectl create secret generic claude-sandbox-secrets \\"
    echo "  --from-literal=GITHUB_TOKEN=\"\$GITHUB_TOKEN\" \\"
    echo "  --from-literal=CLAUDE_CODE_OAUTH_TOKEN=\"\$CLAUDE_CODE_OAUTH_TOKEN\" \\"
    echo "  --from-literal=REPO_URL=\"\$REPO_URL\" \\"
    echo "  --from-literal=TELEGRAM_BOT_TOKEN=\"\$TELEGRAM_BOT_TOKEN\" \\"
    echo "  --from-literal=TELEGRAM_CHAT_ID=\"\$TELEGRAM_CHAT_ID\""
    echo ""
    exit 1
  fi

  log "✓ Secrets configured"
}

# Test basic job
test_basic_job() {
  local job_name="claude-test-$(date +%s)"
  local task="${1:-list files and show git status}"

  log "Creating test job: $job_name"
  info "Task: $task"

  export TASK="$task"
  export JOB_NAME="$job_name"

  # Auto-detect CLAUDE_IMAGE from git remote origin owner if not set
  if [ -z "$CLAUDE_IMAGE" ]; then
    local owner=$(get_repo_owner "$SANDBOX_DIR")
    if [ -n "$owner" ]; then
      export CLAUDE_IMAGE="${owner}/claude-sandbox:latest"
      log "Auto-detected CLAUDE_IMAGE: $CLAUDE_IMAGE"
    else
      # Fallback to original hardcoded value if can't detect
      export CLAUDE_IMAGE="landovsky/claude-sandbox:latest"
      warn "Could not detect repository owner, using default: $CLAUDE_IMAGE"
    fi
  fi

  # Apply job
  envsubst < "$SCRIPT_DIR/job-template-test.yaml" | kubectl apply -f -

  log "Job created. Waiting for pod to start..."

  # Wait for pod to be created
  local pod_name=""
  for i in {1..30}; do
    pod_name=$(kubectl get pods -l job-name="$job_name" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$pod_name" ]; then
      break
    fi
    sleep 2
  done

  if [ -z "$pod_name" ]; then
    error "Pod not created after 60s"
    return 1
  fi

  log "Pod created: $pod_name"
  log "Streaming logs (Ctrl+C to stop following, job will continue)..."
  echo ""

  # Follow logs
  kubectl logs -f "$pod_name" -c claude || true

  echo ""
  log "Log streaming ended"

  # Check final status
  local phase=$(kubectl get pod "$pod_name" -o jsonpath='{.status.phase}')
  info "Final pod phase: $phase"

  # Show job status
  kubectl get job "$job_name"

  echo ""
  log "To view logs again: kubectl logs $pod_name -c claude"
  log "To delete job: kubectl delete job $job_name"
}

# Clean up old test jobs
cleanup_test_jobs() {
  log "Cleaning up old test jobs..."
  kubectl delete jobs -l test=true --field-selector status.successful=1 2>/dev/null || true
  kubectl delete jobs -l test=true --field-selector status.failed=1 2>/dev/null || true
  log "✓ Cleanup complete"
}

# Main
case "${1:-test}" in
  test)
    check_prereqs
    check_secrets
    test_basic_job "${@:2}"
    ;;
  cleanup)
    cleanup_test_jobs
    ;;
  check)
    check_prereqs
    check_secrets
    log "✓ All checks passed"
    ;;
  *)
    echo "Usage: $0 [test|cleanup|check] [task]"
    echo ""
    echo "Commands:"
    echo "  test [task]  - Run test job (default task: 'list files and show git status')"
    echo "  cleanup      - Delete completed/failed test jobs"
    echo "  check        - Check prerequisites and secrets"
    echo ""
    echo "Environment variables:"
    echo "  CLAUDE_IMAGE - Docker image to use (required)"
    echo ""
    echo "Examples:"
    echo "  CLAUDE_IMAGE=ghcr.io/user/claude-sandbox:latest $0 test"
    echo "  CLAUDE_IMAGE=ghcr.io/user/claude-sandbox:latest $0 test 'create a README file'"
    exit 1
    ;;
esac
