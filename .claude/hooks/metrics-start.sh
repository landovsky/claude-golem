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

# Filter: Only track workflow stages (analyst, planner, implementer, reviewer)
# Skip master, general-purpose, and other agents
if [[ ! "$agent_type" =~ ^(analyst|planner|implementer|reviewer)$ ]]; then
  # Silently exit - this agent is not part of the workflow we're tracking
  exit 0
fi

# Get timestamp in ISO 8601 format
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get task from environment variable or extract from hook input
task_raw="${TASK:-}"

# If TASK not set, try to extract from agent prompt (master usually passes task ID in prompt)
if [[ -z "$task_raw" ]]; then
  # Try to extract beads task ID pattern (e.g., .claude-123, task-123.1, .claude-abc.2)
  task_raw=$(echo "$HOOK_INPUT" | jq -r '.prompt' 2>/dev/null | grep -oE '\.(claude|task)-[a-z0-9]+(\.[0-9]+)?' | head -1 || echo "")
fi

# Fallback to "unknown-task" if still empty
task_raw="${task_raw:-unknown-task}"

# Truncate to 50 chars
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
