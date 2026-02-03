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
agent_transcript_path=$(echo "$HOOK_INPUT" | jq -r '.agent_transcript_path' 2>/dev/null || echo "")

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

# Parse transcript for token usage (Phase 2)
input_tokens=0
output_tokens=0
cache_read_tokens=0
cache_creation_tokens=0
model="null"
cost_usd="null"

if [[ -n "$agent_transcript_path" && -f "$agent_transcript_path" ]]; then
  # Sum token counts across all assistant messages using jq
  input_tokens=$(grep '"type":"assistant"' "$agent_transcript_path" 2>/dev/null | \
    jq -s '[.[] | .message.usage.input_tokens // 0] | add // 0' 2>/dev/null || echo 0)

  output_tokens=$(grep '"type":"assistant"' "$agent_transcript_path" 2>/dev/null | \
    jq -s '[.[] | .message.usage.output_tokens // 0] | add // 0' 2>/dev/null || echo 0)

  cache_read_tokens=$(grep '"type":"assistant"' "$agent_transcript_path" 2>/dev/null | \
    jq -s '[.[] | .message.usage.cache_read_input_tokens // 0] | add // 0' 2>/dev/null || echo 0)

  cache_creation_tokens=$(grep '"type":"assistant"' "$agent_transcript_path" 2>/dev/null | \
    jq -s '[.[] | (.message.usage.cache_creation.ephemeral_5m_input_tokens // 0) + (.message.usage.cache_creation.ephemeral_1h_input_tokens // 0)] | add // 0' 2>/dev/null || echo 0)

  # Extract model from last assistant message
  model=$(grep '"type":"assistant"' "$agent_transcript_path" 2>/dev/null | tail -1 | \
    jq -r '.message.model // "null"' 2>/dev/null || echo "null")

  # Calculate cost if we have token data
  if [[ "$model" != "null" && ( "$input_tokens" -gt 0 || "$output_tokens" -gt 0 ) ]]; then
    # Map model to pricing tier
    case "$model" in
      *opus-4.5*|*opus-4-5*)
        input_rate=5.00; output_rate=25.00; cache_read_rate=0.50; cache_write_rate=6.25 ;;
      *opus-4*)
        input_rate=15.00; output_rate=75.00; cache_read_rate=1.50; cache_write_rate=18.75 ;;
      *sonnet-4*)
        input_rate=3.00; output_rate=15.00; cache_read_rate=0.30; cache_write_rate=3.75 ;;
      *haiku-4.5*|*haiku-4-5*)
        input_rate=1.00; output_rate=5.00; cache_read_rate=0.10; cache_write_rate=1.25 ;;
      *haiku-3.5*|*haiku-3-5*)
        input_rate=0.80; output_rate=4.00; cache_read_rate=0.08; cache_write_rate=1.00 ;;
      *)
        # Unknown model - fallback to sonnet pricing
        input_rate=3.00; output_rate=15.00; cache_read_rate=0.30; cache_write_rate=3.75 ;;
    esac

    # Calculate cost with awk (handles floats)
    cost_usd=$(awk -v in_tok="$input_tokens" -v out_tok="$output_tokens" \
                    -v cache_r="$cache_read_tokens" -v cache_c="$cache_creation_tokens" \
                    -v in_rate="$input_rate" -v out_rate="$output_rate" \
                    -v cr_rate="$cache_read_rate" -v cw_rate="$cache_write_rate" \
                    'BEGIN {
                      cost = (in_tok * in_rate / 1000000) + \
                             (out_tok * out_rate / 1000000) + \
                             (cache_r * cr_rate / 1000000) + \
                             (cache_c * cw_rate / 1000000)
                      printf "%.4f", cost
                    }' 2>/dev/null || echo "null")
  fi
fi

# Build end event JSON with real token data (Phase 2)
json=$(jq -nc \
  --arg event "stage_end" \
  --arg timestamp "$timestamp" \
  --arg session_id "$session_id" \
  --arg agent_id "$agent_id" \
  --arg stage "$agent_type" \
  --arg task "$task" \
  --argjson duration "$duration_seconds" \
  --arg status "$status" \
  --argjson input_tokens "$input_tokens" \
  --argjson output_tokens "$output_tokens" \
  --argjson cache_read_tokens "$cache_read_tokens" \
  --argjson cache_creation_tokens "$cache_creation_tokens" \
  --arg model "$model" \
  --arg cost_usd "$cost_usd" \
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
      input: ($input_tokens | if . == 0 then null else . end),
      output: ($output_tokens | if . == 0 then null else . end),
      cache_read: ($cache_read_tokens | if . == 0 then null else . end),
      cache_creation: ($cache_creation_tokens | if . == 0 then null else . end)
    },
    cost_usd: (if $cost_usd == "null" then null else ($cost_usd | tonumber) end),
    model: (if $model == "null" then null else $model end)
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

  # Format token display
  if [[ "$input_tokens" -gt 0 || "$output_tokens" -gt 0 ]]; then
    tokens_str=$(printf "%'d in / %'d out" "$input_tokens" "$output_tokens")
    if [[ "$cache_read_tokens" -gt 0 ]]; then
      tokens_str="$tokens_str / $(printf "%'d" "$cache_read_tokens") cache"
    fi
    cost_str="\$$cost_usd"
    model_str="$model"
  else
    tokens_str="--"
    cost_str="--"
    model_str="--"
  fi

  # Build comment
  comment=$(cat <<EOF
## Stage Metrics
- **Stage**: $agent_type
- **Task**: $task
- **Duration**: $duration_str
- **Tokens**: $tokens_str
- **Cost**: $cost_str
- **Model**: $model_str
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
