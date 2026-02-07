#!/bin/bash
# notify-telegram.sh - Send notification to Telegram when Claude session ends
#
# Usage: notify-telegram.sh <exit_code>
#
# Required environment variables:
#   TELEGRAM_BOT_TOKEN - Bot token from @BotFather
#   TELEGRAM_CHAT_ID   - Chat ID to send messages to
#
# Optional environment variables:
#   TASK              - Task description (for context in message)
#   REPO_URL          - Repository URL
#   SANDBOX_MODE      - Sandbox kind: "local" or "remote"

EXIT_CODE="${1:-0}"
TASK="${TASK:-unknown task}"
REPO_URL="${REPO_URL:-unknown repo}"
SANDBOX_MODE="${SANDBOX_MODE:-unknown}"

# Skip if Telegram not configured
if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
  echo "[notify] Telegram not configured, skipping notification"
  exit 0
fi

# Determine status emoji and text
if [ "$EXIT_CODE" -eq 0 ]; then
  STATUS="✅ Completed"
elif [ "$EXIT_CODE" -eq 130 ]; then
  STATUS="⚠️ Interrupted (Ctrl+C)"
elif [ "$EXIT_CODE" -eq 137 ]; then
  STATUS="💀 Killed (OOM or timeout)"
else
  STATUS="❌ Failed (exit code: $EXIT_CODE)"
fi

# Get git info if available
GIT_BRANCH=""
GIT_COMMIT=""
if [ -d "/workspace/.git" ]; then
  cd /workspace
  GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
  GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
fi

# Extract repo name from URL
REPO_NAME=$(echo "$REPO_URL" | sed 's|.*/||' | sed 's|\.git$||')

# Build message
# Mode indicator
if [ "$SANDBOX_MODE" = "local" ]; then
  MODE_LABEL="🏠 local"
elif [ "$SANDBOX_MODE" = "remote" ]; then
  MODE_LABEL="☁️ remote"
else
  MODE_LABEL="$SANDBOX_MODE"
fi

MESSAGE="🤖 *Claude Sandbox* (${MODE_LABEL})

$STATUS

📋 *Task:* \`${TASK}\`
📦 *Repo:* ${REPO_NAME}
🌿 *Branch:* ${GIT_BRANCH}
📝 *Commit:* ${GIT_COMMIT}"

# Send to Telegram
response=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d chat_id="${TELEGRAM_CHAT_ID}" \
  -d text="$MESSAGE" \
  -d parse_mode="Markdown" \
  -w "\n%{http_code}")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n-1)

if [ "$http_code" -eq 200 ]; then
  echo "[notify] Telegram notification sent"
else
  echo "[notify] Failed to send Telegram notification (HTTP $http_code)"
  echo "[notify] Response: $body"
fi
