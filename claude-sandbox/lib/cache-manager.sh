#!/bin/bash
# cache-manager.sh - S3-backed dependency caching for Ruby, Node, and other package managers
#
# Usage:
#   source lib/cache-manager.sh
#   cache_restore "bundle" "Gemfile.lock" "vendor/bundle"
#   cache_save "bundle" "Gemfile.lock" "vendor/bundle"
#
# Environment variables required:
#   AWS_ACCESS_KEY_ID - AWS access key (from K8s secret)
#   AWS_SECRET_ACCESS_KEY - AWS secret key (from K8s secret)
#   AWS_REGION - AWS region (default: us-east-1)
#   CACHE_S3_BUCKET - S3 bucket name for caching
#   CACHE_S3_PREFIX - Optional prefix for cache keys (default: claude-sandbox-cache)
#   AWS_ENDPOINT_URL - Optional custom S3 endpoint (for Digital Ocean Spaces, etc.)

set -euo pipefail

# Colors for output
readonly CACHE_COLOR="\033[1;35m"  # Magenta
readonly RESET="\033[0m"

# Default configuration
: "${AWS_REGION:=us-east-1}"
: "${CACHE_S3_PREFIX:=claude-sandbox-cache}"
: "${CACHE_COMPRESSION:=true}"
: "${CACHE_VERBOSE:=false}"
: "${AWS_ENDPOINT_URL:=}"

# Cache operation timeout (seconds)
readonly CACHE_TIMEOUT=300

# Helper function to build AWS CLI arguments
aws_s3_args() {
  local args="--region ${AWS_REGION}"
  if [ -n "${AWS_ENDPOINT_URL}" ]; then
    args="$args --endpoint-url ${AWS_ENDPOINT_URL}"
  fi
  echo "$args"
}

# Check if caching is enabled
cache_is_enabled() {
  if [ -z "${CACHE_S3_BUCKET:-}" ]; then
    return 1
  fi

  if [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
    return 1
  fi

  return 0
}

# Log cache operations
cache_log() {
  if [ "${CACHE_VERBOSE}" = "true" ]; then
    echo -e "${CACHE_COLOR}[cache]${RESET} $*" >&2
  fi
}

# Calculate hash of lockfile
# Args: lockfile_path
# Returns: hash string (sha256 first 16 chars)
cache_hash() {
  local lockfile="$1"

  if [ ! -f "$lockfile" ]; then
    echo "ERROR: Lockfile not found: $lockfile" >&2
    return 1
  fi

  # Use sha256sum for better collision resistance than md5
  sha256sum "$lockfile" | cut -d' ' -f1 | cut -c1-16
}

# Generate S3 key for cache
# Args: cache_type, lockfile_hash
# Returns: s3://bucket/prefix/stack/type-hash.tar.gz
# Key structure: prefix/ruby/bundle-abc123.tar.gz, prefix/node/npm-def456.tar.gz
cache_key() {
  local cache_type="$1"
  local lockfile_hash="$2"
  local extension=".tar.gz"

  if [ "${CACHE_COMPRESSION}" = "false" ]; then
    extension=".tar"
  fi

  # Map cache_type to tech stack folder
  local stack
  case "$cache_type" in
    bundle)  stack="ruby" ;;
    npm)     stack="node" ;;
    pip)     stack="python" ;;
    cargo)   stack="rust" ;;
    gomod)   stack="go" ;;
    *)       stack="$cache_type" ;;
  esac

  echo "s3://${CACHE_S3_BUCKET}/${CACHE_S3_PREFIX}/${stack}/${cache_type}-${lockfile_hash}${extension}"
}

# Check if cache exists in S3
# Args: s3_key
# Returns: 0 if exists, 1 if not
cache_exists() {
  local s3_key="$1"

  cache_log "Checking cache existence: $s3_key"

  timeout ${CACHE_TIMEOUT} aws s3 ls "$s3_key" $(aws_s3_args) >/dev/null 2>&1
}

# Restore dependencies from S3 cache
# Args: cache_type (e.g., "bundle", "npm"), lockfile_path, target_dir
# Returns: 0 if restored, 1 if not found or error
cache_restore() {
  local cache_type="$1"
  local lockfile="$2"
  local target_dir="$3"

  if ! cache_is_enabled; then
    cache_log "Caching disabled (missing S3 config or credentials)"
    return 1
  fi

  if [ ! -f "$lockfile" ]; then
    cache_log "Lockfile not found: $lockfile"
    return 1
  fi

  local lockfile_hash
  lockfile_hash=$(cache_hash "$lockfile")

  local s3_key
  s3_key=$(cache_key "$cache_type" "$lockfile_hash")

  cache_log "Attempting to restore from cache: $s3_key"

  if ! cache_exists "$s3_key"; then
    cache_log "Cache miss for $cache_type ($lockfile_hash)"
    return 1
  fi

  cache_log "Cache hit! Downloading from S3..."

  # Create target directory if it doesn't exist
  mkdir -p "$target_dir"

  # Download and extract
  local temp_archive="/tmp/cache-${cache_type}-${lockfile_hash}.tar.gz"

  if timeout ${CACHE_TIMEOUT} aws s3 cp "$s3_key" "$temp_archive" $(aws_s3_args) --quiet; then
    cache_log "Extracting cache to $target_dir..."

    if [ "${CACHE_COMPRESSION}" = "true" ]; then
      tar -xzf "$temp_archive" -C "$target_dir" --strip-components=1
    else
      tar -xf "$temp_archive" -C "$target_dir" --strip-components=1
    fi

    rm -f "$temp_archive"

    # Create marker file with hash
    local marker_dir
    case "$cache_type" in
      bundle)
        marker_dir=".bundle"
        ;;
      npm)
        marker_dir="node_modules"
        ;;
      *)
        marker_dir="$target_dir"
        ;;
    esac

    mkdir -p "$marker_dir"
    # Store full sha256 in marker for compatibility with existing checks
    sha256sum "$lockfile" | cut -d' ' -f1 > "${marker_dir}/.installed"

    cache_log "Cache restored successfully"
    return 0
  else
    cache_log "Failed to download cache from S3"
    rm -f "$temp_archive"
    return 1
  fi
}

# Save dependencies to S3 cache
# Args: cache_type (e.g., "bundle", "npm"), lockfile_path, source_dir
# Returns: 0 if saved, 1 if error
cache_save() {
  local cache_type="$1"
  local lockfile="$2"
  local source_dir="$3"

  if ! cache_is_enabled; then
    cache_log "Caching disabled (missing S3 config or credentials)"
    return 1
  fi

  if [ ! -f "$lockfile" ]; then
    cache_log "Lockfile not found: $lockfile"
    return 1
  fi

  if [ ! -d "$source_dir" ]; then
    cache_log "Source directory not found: $source_dir"
    return 1
  fi

  local lockfile_hash
  lockfile_hash=$(cache_hash "$lockfile")

  local s3_key
  s3_key=$(cache_key "$cache_type" "$lockfile_hash")

  # Check if already cached
  if cache_exists "$s3_key"; then
    cache_log "Cache already exists: $s3_key"
    return 0
  fi

  cache_log "Saving to cache: $s3_key"

  local temp_archive="/tmp/cache-${cache_type}-${lockfile_hash}.tar.gz"

  # Create archive
  cache_log "Creating archive from $source_dir..."

  if [ "${CACHE_COMPRESSION}" = "true" ]; then
    tar -czf "$temp_archive" -C "$(dirname "$source_dir")" "$(basename "$source_dir")"
  else
    tar -cf "$temp_archive" -C "$(dirname "$source_dir")" "$(basename "$source_dir")"
  fi

  # Upload to S3
  if timeout ${CACHE_TIMEOUT} aws s3 cp "$temp_archive" "$s3_key" $(aws_s3_args) --quiet; then
    cache_log "Cache saved successfully"
    rm -f "$temp_archive"
    return 0
  else
    cache_log "Failed to upload cache to S3"
    rm -f "$temp_archive"
    return 1
  fi
}

# Prune old cache entries (optional cleanup function)
# Args: cache_type, days_to_keep
# Note: This is expensive (lists all objects), use sparingly
cache_prune() {
  local cache_type="$1"
  local days_to_keep="${2:-30}"

  if ! cache_is_enabled; then
    cache_log "Caching disabled"
    return 1
  fi

  cache_log "Pruning $cache_type caches older than $days_to_keep days..."

  local prefix="${CACHE_S3_PREFIX}/${cache_type}-"

  # List and delete old objects
  local api_args="--bucket ${CACHE_S3_BUCKET} --prefix $prefix --region ${AWS_REGION}"
  if [ -n "${AWS_ENDPOINT_URL}" ]; then
    api_args="$api_args --endpoint-url ${AWS_ENDPOINT_URL}"
  fi

  aws s3api list-objects-v2 $api_args \
    --query "Contents[?LastModified<='$(date -d "${days_to_keep} days ago" -Iseconds)'].Key" \
    --output text | \
  while read -r key; do
    if [ -n "$key" ]; then
      cache_log "Deleting old cache: s3://${CACHE_S3_BUCKET}/${key}"
      aws s3 rm "s3://${CACHE_S3_BUCKET}/${key}" $(aws_s3_args) --quiet
    fi
  done

  cache_log "Prune complete"
}
