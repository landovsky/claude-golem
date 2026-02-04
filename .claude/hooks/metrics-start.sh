#!/bin/bash

# Metrics Start Hook
# Captures stage start event when subagent begins
# Writes to workflow-metrics.jsonl for persistence

# Exit 0 always - hook failures must not break workflow
set +e

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Extract fields from hook JSON
agent_id=$(echo "$HOOK_INPUT" | jq -r '.agent_id' 2>/dev/null || echo "unknown-agent")
agent_type=$(echo "$HOOK_INPUT" | jq -r '.agent_type' 2>/dev/null || echo "unknown")
session_id=$(echo "$HOOK_INPUT" | jq -r '.session_id' 2>/dev/null || echo "unknown-session")

# Get timestamp in ISO 8601 format
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get task from environment variable, truncate to 50 chars, fallback to unknown
task_raw="${TASK:-unknown-task}"
task=$(echo "$task_raw" | cut -c1-50)

# JSONL file path
JSONL_FILE="/Users/tomas/.claude/workflow-metrics.jsonl"

# Ensure directory exists
mkdir -p "$(dirname "$JSONL_FILE")" 2>/dev/null || true

# Build JSON with jq for safe escaping (compact format for JSONL)
json=$(jq -nc \
  --arg event "stage_start" \
  --arg timestamp "$timestamp" \
  --arg session_id "$session_id" \
  --arg agent_id "$agent_id" \
  --arg stage "$agent_type" \
  --arg task "$task" \
  '{
    event: $event,
    timestamp: $timestamp,
    session_id: $session_id,
    agent_id: $agent_id,
    stage: $stage,
    task: $task,
    model: null
  }' 2>/dev/null)

# Append to JSONL if json generation succeeded
if [[ -n "$json" ]]; then
  echo "$json" >> "$JSONL_FILE" 2>/dev/null || true
fi

# Exit 0 always
exit 0
