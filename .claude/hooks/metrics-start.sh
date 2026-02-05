#!/bin/bash

# Metrics Start Hook
# Captures stage start event when subagent begins
# Writes to workflow-metrics.jsonl for persistence

# Exit 0 always - hook failures must not break workflow
set +e

# Debug logging (append to debug log file)
DEBUG_LOG="/Users/tomas/.claude/hooks-debug.log"
echo "=== METRICS-START HOOK FIRED ===" >> "$DEBUG_LOG" 2>/dev/null || true
echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$DEBUG_LOG" 2>/dev/null || true
echo "PWD: $PWD" >> "$DEBUG_LOG" 2>/dev/null || true
echo "CLAUDE_PROJECT_DIR: ${CLAUDE_PROJECT_DIR:-<not set>}" >> "$DEBUG_LOG" 2>/dev/null || true
echo "TASK: ${TASK:-<not set>}" >> "$DEBUG_LOG" 2>/dev/null || true
echo "USER: ${USER:-<not set>}" >> "$DEBUG_LOG" 2>/dev/null || true
echo "HOME: ${HOME:-<not set>}" >> "$DEBUG_LOG" 2>/dev/null || true

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Debug: Log raw hook input
echo "Hook input (first 500 chars): ${HOOK_INPUT:0:500}" >> "$DEBUG_LOG" 2>/dev/null || true

# Extract fields from hook JSON
agent_id=$(echo "$HOOK_INPUT" | jq -r '.agent_id' 2>/dev/null || echo "unknown-agent")
agent_type=$(echo "$HOOK_INPUT" | jq -r '.agent_type' 2>/dev/null || echo "unknown")
session_id=$(echo "$HOOK_INPUT" | jq -r '.session_id' 2>/dev/null || echo "unknown-session")
agent_transcript_path=$(echo "$HOOK_INPUT" | jq -r '.agent_transcript_path' 2>/dev/null || echo "")

# Debug: Log parsed values
echo "Parsed - agent_id: $agent_id, agent_type: $agent_type, session_id: $session_id" >> "$DEBUG_LOG" 2>/dev/null || true
echo "Parsed - transcript_path: $agent_transcript_path" >> "$DEBUG_LOG" 2>/dev/null || true

# Filter: Only track workflow stages (analyst, planner, implementer, reviewer)
# Skip master, general-purpose, and other agents
if [[ ! "$agent_type" =~ ^(analyst|planner|implementer|reviewer)$ ]]; then
  # Silently exit - this agent is not part of the workflow we're tracking
  exit 0
fi

# Get timestamp in ISO 8601 format
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get task from environment variable or extract from agent transcript
task_raw="${TASK:-}"

# If TASK not set, try to extract from agent transcript (first user message contains task ID)
if [[ -z "$task_raw" && -n "$agent_transcript_path" && -f "$agent_transcript_path" ]]; then
  # Extract first user message and look for task ID pattern
  task_raw=$(head -1 "$agent_transcript_path" 2>/dev/null | \
    jq -r '.message.content' 2>/dev/null | \
    grep -oE '\.(claude|task)-[a-z0-9]+(\.[0-9]+)?' | \
    head -1 || echo "")
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
  echo "$json" >> "$JSONL_FILE" 2>/dev/null
  write_result=$?
  echo "JSON generated: ${json:0:200}" >> "$DEBUG_LOG" 2>/dev/null || true
  echo "Write to $JSONL_FILE: exit_code=$write_result" >> "$DEBUG_LOG" 2>/dev/null || true
  echo "File exists after write: $(test -f "$JSONL_FILE" && echo 'yes' || echo 'no')" >> "$DEBUG_LOG" 2>/dev/null || true
else
  echo "ERROR: JSON generation failed" >> "$DEBUG_LOG" 2>/dev/null || true
fi

echo "=== METRICS-START HOOK COMPLETE ===" >> "$DEBUG_LOG" 2>/dev/null || true
echo "" >> "$DEBUG_LOG" 2>/dev/null || true

# Exit 0 always
exit 0
