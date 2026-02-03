#!/bin/bash

# Metrics End Hook
# Captures stage end event with duration calculation
# Posts metrics summary as bd comment on subtask

# Exit 0 always - hook failures must not break workflow
set +e

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Extract fields from hook JSON
agent_id=$(echo "$HOOK_INPUT" | jq -r '.agent_id' 2>/dev/null || echo "unknown-agent")
agent_type=$(echo "$HOOK_INPUT" | jq -r '.agent_type' 2>/dev/null || echo "unknown")
session_id=$(echo "$HOOK_INPUT" | jq -r '.session_id' 2>/dev/null || echo "unknown-session")
transcript_path=$(echo "$HOOK_INPUT" | jq -r '.transcript_path' 2>/dev/null || echo "")

# Get timestamp in ISO 8601 format
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get task from environment variable, truncate to 50 chars
task_raw="${TASK:-unknown-task}"
task=$(echo "$task_raw" | cut -c1-50)

# JSONL file path
JSONL_FILE="/Users/tomas/.claude/workflow-metrics.jsonl"

# Find matching start event for this agent_id
start_event=""
if [[ -f "$JSONL_FILE" ]]; then
  # Find most recent start event for this agent_id
  start_event=$(grep "\"agent_id\":\"$agent_id\"" "$JSONL_FILE" 2>/dev/null | grep "stage_start" | tail -1)
fi

# Calculate duration
duration_seconds=0
if [[ -n "$start_event" ]]; then
  start_time=$(echo "$start_event" | jq -r '.timestamp' 2>/dev/null || echo "")

  if [[ -n "$start_time" ]]; then
    # Portable duration calculation (works on macOS and Linux)
    if command -v gdate >/dev/null 2>&1; then
      # GNU date (via brew on macOS)
      start_epoch=$(gdate -d "$start_time" +%s 2>/dev/null || echo 0)
      end_epoch=$(gdate +%s)
    elif date --version >/dev/null 2>&1; then
      # GNU date (Linux)
      start_epoch=$(date -d "$start_time" +%s 2>/dev/null || echo 0)
      end_epoch=$(date +%s)
    else
      # BSD date (macOS default)
      start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$start_time" +%s 2>/dev/null || echo 0)
      end_epoch=$(date -u +%s)
    fi
    duration_seconds=$((end_epoch - start_epoch))
  fi
fi

# Detect status from transcript (simplified - just check for "blocked")
status="completed"
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
  if grep -qi "blocked" "$transcript_path" 2>/dev/null; then
    status="blocked"
  fi
fi

# Build end event JSON with token fields (all null in Phase 1) - compact format for JSONL
json=$(jq -nc \
  --arg event "stage_end" \
  --arg timestamp "$timestamp" \
  --arg session_id "$session_id" \
  --arg agent_id "$agent_id" \
  --arg stage "$agent_type" \
  --arg task "$task" \
  --argjson duration "$duration_seconds" \
  --arg status "$status" \
  '{
    event: $event,
    timestamp: $timestamp,
    session_id: $session_id,
    agent_id: $agent_id,
    stage: $stage,
    task: $task,
    duration_seconds: $duration,
    status: $status,
    tokens: {
      input: null,
      output: null,
      cache_read: null,
      cache_creation: null
    },
    cost_usd: null,
    model: null
  }' 2>/dev/null)

# Append to JSONL if json generation succeeded
if [[ -n "$json" ]]; then
  echo "$json" >> "$JSONL_FILE" 2>/dev/null || true
fi

# Post bd comment with metrics summary (optional - allow to fail gracefully)
# Only if TASK looks like a task ID (contains a dot, e.g., task-123.1)
if [[ "$task_raw" =~ \. ]]; then
  # Format duration as human-readable (minutes and seconds)
  minutes=$((duration_seconds / 60))
  seconds=$((duration_seconds % 60))
  duration_str="${minutes}m ${seconds}s"

  # Build comment
  comment=$(cat <<EOF
## Stage Metrics
- **Stage**: $agent_type
- **Task**: $task
- **Duration**: $duration_str
- **Tokens**: -- (Phase 2)
- **Cost**: -- (Phase 2)
- **Session**: $session_id
- **Recorded**: $timestamp
EOF
)

  # Post comment (allow to fail gracefully)
  if command -v bd >/dev/null 2>&1; then
    bd comments add "$task_raw" "$comment" 2>/dev/null || true
  fi
fi

# Exit 0 always
exit 0
