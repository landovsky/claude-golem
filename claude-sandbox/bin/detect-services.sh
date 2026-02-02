#!/bin/bash
# Detect required services from repository before container starts
# Returns space-separated list of profiles: "claude with-postgres with-redis"

set -e

REPO_URL="$1"

# Always include claude service
profiles="claude"

# Try to detect from local repo if we're in it
if [ -d "$PWD/.git" ]; then
  current_remote=$(git -C "$PWD" remote get-url origin 2>/dev/null || echo "")
  if [ "$current_remote" = "$REPO_URL" ] || [ -z "$REPO_URL" ]; then
    # We're in target repo, can read files directly
    if [ -f "$PWD/Gemfile" ]; then
      if grep -q "gem ['\"]pg['\"]" "$PWD/Gemfile" 2>/dev/null; then
        profiles="$profiles with-postgres"
      fi
      if grep -q "gem ['\"]redis['\"]" "$PWD/Gemfile" 2>/dev/null || \
         grep -q "gem ['\"]sidekiq['\"]" "$PWD/Gemfile" 2>/dev/null; then
        profiles="$profiles with-redis"
      fi
    fi

    if [ -f "$PWD/package.json" ]; then
      if grep -q "\"pg\"" "$PWD/package.json" 2>/dev/null; then
        profiles="$profiles with-postgres"
      fi
      if grep -q "\"redis\"" "$PWD/package.json" 2>/dev/null || \
         grep -q "\"bull\"" "$PWD/package.json" 2>/dev/null || \
         grep -q "\"bullmq\"" "$PWD/package.json" 2>/dev/null; then
        profiles="$profiles with-redis"
      fi
    fi

    # Deduplicate
    profiles=$(echo "$profiles" | tr ' ' '\n' | sort -u | tr '\n' ' ')
    echo "$profiles"
    exit 0
  fi
fi

# Try git archive for remote repos
temp_dir=$(mktemp -d)
trap "rm -rf $temp_dir" EXIT

# Embed GITHUB_TOKEN in HTTPS URLs for authentication
ARCHIVE_URL="$REPO_URL"
if [[ "$REPO_URL" =~ ^https://github\.com/ ]] && [ -n "$GITHUB_TOKEN" ]; then
  ARCHIVE_URL=$(echo "$REPO_URL" | sed "s|https://|https://x-access-token:${GITHUB_TOKEN}@|")
fi

git archive --remote="$ARCHIVE_URL" HEAD Gemfile 2>/dev/null | tar -xC "$temp_dir" 2>/dev/null || true
git archive --remote="$ARCHIVE_URL" HEAD package.json 2>/dev/null | tar -xC "$temp_dir" 2>/dev/null || true

if [ -f "$temp_dir/Gemfile" ]; then
  if grep -q "gem ['\"]pg['\"][,[:space:]]" "$temp_dir/Gemfile" 2>/dev/null; then
    profiles="$profiles with-postgres"
  fi
  if grep -q "gem ['\"]redis['\"][,[:space:]]" "$temp_dir/Gemfile" 2>/dev/null || \
     grep -q "gem ['\"]sidekiq['\"][,[:space:]]" "$temp_dir/Gemfile" 2>/dev/null; then
    profiles="$profiles with-redis"
  fi
fi

if [ -f "$temp_dir/package.json" ]; then
  if grep -q "\"pg\"" "$temp_dir/package.json" 2>/dev/null; then
    profiles="$profiles with-postgres"
  fi
  if grep -q "\"redis\"" "$temp_dir/package.json" 2>/dev/null || \
     grep -q "\"bull\"" "$temp_dir/package.json" 2>/dev/null || \
     grep -q "\"bullmq\"" "$temp_dir/package.json" 2>/dev/null; then
    profiles="$profiles with-redis"
  fi
fi

# Deduplicate
profiles=$(echo "$profiles" | tr ' ' '\n' | sort -u | tr '\n' ' ')

# Fail-open: if no services detected and no files were found, include all services
if [ "$profiles" = "claude " ] && [ ! -f "$temp_dir/Gemfile" ] && [ ! -f "$temp_dir/package.json" ]; then
  echo "claude with-postgres with-redis"
else
  echo "$profiles"
fi
