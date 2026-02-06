#!/bin/bash
# update-secrets.sh - Update k8s claude-sandbox-secrets from local environment
#
# Usage:
#   export GITHUB_TOKEN="ghp_..."
#   export CLAUDE_CODE_OAUTH_TOKEN="sk-ant-oat01-..."
#   export REPO_URL="https://github.com/user/repo.git"
#   export TELEGRAM_BOT_TOKEN="123456789:ABC..."
#   export TELEGRAM_CHAT_ID="-100..."
#
#   ./bin/update-secrets.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[update-secrets]${NC} $1"; }
warn() { echo -e "${YELLOW}[update-secrets]${NC} $1"; }
error() { echo -e "${RED}[update-secrets]${NC} $1" >&2; }

# Check required variables
REQUIRED_VARS=(
    "GITHUB_TOKEN"
    "CLAUDE_CODE_OAUTH_TOKEN"
)

OPTIONAL_VARS=(
    "TELEGRAM_BOT_TOKEN"
    "TELEGRAM_CHAT_ID"
    "AWS_ACCESS_KEY_ID"
    "AWS_SECRET_ACCESS_KEY"
    "AWS_REGION"
    "CACHE_S3_BUCKET"
    "CACHE_S3_PREFIX"
)

missing=0
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        error "Missing required variable: $var"
        missing=1
    fi
done

if [ $missing -eq 1 ]; then
    error "Set required variables before running this script"
    exit 1
fi

log "Building secret data..."

# Build the --from-literal arguments
ARGS=()
for var in "${REQUIRED_VARS[@]}" "${OPTIONAL_VARS[@]}"; do
    if [ -n "${!var}" ]; then
        ARGS+=("--from-literal=$var=${!var}")
        log "  ✓ $var"
    fi
done

# Delete existing secret if it exists
if kubectl get secret claude-sandbox-secrets &> /dev/null; then
    warn "Deleting existing secret..."
    kubectl delete secret claude-sandbox-secrets
fi

# Create new secret
log "Creating secret claude-sandbox-secrets..."
kubectl create secret generic claude-sandbox-secrets "${ARGS[@]}"

log "✓ Secret updated successfully"

# Verify
echo ""
log "Secret keys:"
kubectl get secret claude-sandbox-secrets -o jsonpath='{.data}' | jq -r 'keys[]' | sed 's/^/  - /'
