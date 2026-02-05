# Usage Metrics Collection

**Status:** Experimental (Phase 1 + 2 complete)

Automatic tracking of token usage, costs, and duration for workflow stages (analyst, planner, implementer, reviewer). Enables benchmarking, anomaly detection, and resource optimization.

## Table of Contents

- [Overview](#overview)
- [Setup](#setup)
- [How It Works](#how-it-works)
- [Data Format](#data-format)
- [Querying Metrics](#querying-metrics)
- [Use Cases](#use-cases)
- [Current Limitations](#current-limitations)
- [Troubleshooting](#troubleshooting)

## Overview

The usage metrics system captures detailed execution data for each workflow stage:

**What's tracked:**
- Token counts (input, output, cache read, cache creation)
- Cost in USD (model-specific pricing)
- Duration (wall-clock time)
- Model used (e.g., claude-sonnet-4-5-20250929)
- Task context (from `$TASK` environment variable)
- Session correlation (via session_id)

**Where data lives:**
- `.claude/workflow-metrics.jsonl` - Full metrics log (git-tracked, append-only)
- BD comments on subtasks - Human-readable summary per stage

**Implementation phases:**
- ✅ Phase 1: Hook infrastructure, JSONL persistence, BD integration
- ✅ Phase 2: Real token data from transcripts, cost calculation

## Setup

### 1. Install Hook Scripts (Already Complete)

The hook scripts are already in place:
- `.claude/hooks/metrics-start.sh` - Captures stage start events
- `.claude/hooks/metrics-end.sh` - Captures stage end with duration, tokens, cost

### 2. Configure settings.json

**Important:** `settings.json` is user-specific and not tracked in git. You must manually add the hooks configuration.

Add this to your `.claude/settings.json`:

```json
{
  "hooks": {
    "SubagentStart": [
      {
        "matcher": "analyst|planner|implementer|reviewer",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/metrics-start.sh"
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "analyst|planner|implementer|reviewer",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/metrics-end.sh"
          }
        ]
      }
    ]
  }
}
```

**Note:** If you already have hooks configured, merge these into your existing `hooks` object.

### 3. Verify Installation

Run a simple workflow to test:

```bash
# Create a test task
bd create "Test metrics collection" -d "Verify hooks are working" -p 2

# Run a simple workflow (will use fast-track)
/develop .claude-xxx
```

After completion, check:

```bash
# Verify JSONL file exists and has data
cat .claude/workflow-metrics.jsonl

# View latest metrics
tail -5 .claude/workflow-metrics.jsonl | jq .

# Check BD comment on completed task
bd show .claude-xxx
```

## How It Works

### Execution Flow

```
1. Master agent invokes subagent (analyst/planner/implementer/reviewer)
   ↓
2. SubagentStart hook fires → metrics-start.sh
   - Extracts agent_id, agent_type, session_id
   - Gets $TASK from environment (set by master)
   - Records timestamp
   - Writes start event to JSONL
   ↓
3. Subagent executes (minutes to hours)
   ↓
4. SubagentStop hook fires → metrics-end.sh
   - Finds matching start event by agent_id
   - Calculates duration (portable date handling)
   - Parses agent transcript for token usage
   - Extracts model name from API responses
   - Calculates cost using model-specific pricing
   - Writes end event to JSONL
   - Posts summary to BD comment
```

### Token Data Extraction (Phase 2)

The SubagentStop hook parses the agent's transcript file (JSONL format) to extract token usage from API responses:

```json
{
  "type": "assistant",
  "message": {
    "model": "claude-sonnet-4-5-20250929",
    "usage": {
      "input_tokens": 12500,
      "output_tokens": 3200,
      "cache_read_input_tokens": 8000,
      "cache_creation": {
        "ephemeral_5m_input_tokens": 15000,
        "ephemeral_1h_input_tokens": 0
      }
    }
  }
}
```

**Token aggregation:** If a stage makes multiple API calls, tokens are summed across all assistant messages.

**Cost calculation:** Uses model-specific pricing tables:

| Model | Input | Output | Cache Read | Cache Write |
|-------|-------|--------|------------|-------------|
| Opus 4.5 | $5.00 | $25.00 | $0.50 | $6.25 |
| Opus 4 | $15.00 | $75.00 | $1.50 | $18.75 |
| Sonnet 4 | $3.00 | $15.00 | $0.30 | $3.75 |
| Haiku 4.5 | $1.00 | $5.00 | $0.10 | $1.25 |
| Haiku 3.5 | $0.80 | $4.00 | $0.08 | $1.00 |

*(Prices are per million tokens as of Feb 2026)*

Unknown models fall back to Sonnet 4 pricing.

### Error Handling

**Graceful degradation:** If transcript parsing fails for any reason (missing file, malformed JSON, etc.), the hook falls back to null values for tokens/cost - maintaining Phase 1 behavior.

**Exit 0 always:** Hook scripts never break the workflow. All errors are suppressed and logged, but hooks always exit 0.

## Data Format

### JSONL Schema

Each line in `.claude/workflow-metrics.jsonl` is a complete JSON object.

**Start Event:**
```json
{
  "event": "stage_start",
  "timestamp": "2026-02-03T14:23:45Z",
  "session_id": "abc123",
  "agent_id": "agent-xyz",
  "stage": "analyst",
  "task": "Analyze OTLP integration approach",
  "model": null
}
```

**End Event:**
```json
{
  "event": "stage_end",
  "timestamp": "2026-02-03T14:25:32Z",
  "session_id": "abc123",
  "agent_id": "agent-xyz",
  "stage": "analyst",
  "task": "Analyze OTLP integration approach",
  "duration_seconds": 107,
  "status": "completed",
  "tokens": {
    "input": 12500,
    "output": 3200,
    "cache_read": 8000,
    "cache_creation": 15000
  },
  "cost_usd": 0.0523,
  "model": "claude-sonnet-4-5-20250929"
}
```

**Field descriptions:**
- `event`: "stage_start" or "stage_end"
- `timestamp`: ISO 8601 UTC timestamp
- `session_id`: Claude Code session identifier (correlates all stages)
- `agent_id`: Unique agent instance identifier (correlates start/end pair)
- `stage`: Agent type (analyst, planner, implementer, reviewer)
- `task`: Human-readable task description from $TASK env var (truncated to 50 chars)
- `duration_seconds`: Wall-clock time from start to end
- `status`: "completed", "blocked", or "interrupted"
- `tokens.*`: Null if no API calls, otherwise real counts
- `cost_usd`: Calculated cost or null (4 decimal precision)
- `model`: Model identifier or null

### BD Comment Format

Posted to subtask upon stage completion:

```markdown
## Stage Metrics
- **Stage**: planner
- **Task**: Plan OTLP data integration
- **Duration**: 1m 47s
- **Tokens**: 12,500 in / 3,200 out / 8,000 cache
- **Cost**: $0.0523
- **Model**: claude-sonnet-4-5-20250929
- **Session**: abc123
- **Recorded**: 2026-02-03T14:25:32Z
```

If tokens are zero or null, displays `--` instead of counts.

## Querying Metrics

The JSONL format enables powerful queries using `jq`:

### Basic Queries

```bash
# All events for a specific stage
jq 'select(.stage=="analyst")' .claude/workflow-metrics.jsonl

# All completed stages
jq 'select(.event=="stage_end" and .status=="completed")' .claude/workflow-metrics.jsonl

# Failed or blocked stages
jq 'select(.status!="completed")' .claude/workflow-metrics.jsonl

# Stages for a specific task
jq 'select(.task=="Implement OTLP integration")' .claude/workflow-metrics.jsonl

# Events from a specific session
jq 'select(.session_id=="abc123")' .claude/workflow-metrics.jsonl
```

### Aggregation Queries

```bash
# Total cost by stage
jq -s 'group_by(.stage) | map({
  stage: .[0].stage,
  total_cost: (map(.cost_usd // 0) | add),
  count: length
})' .claude/workflow-metrics.jsonl

# Average duration by stage
jq -s 'group_by(.stage) | map({
  stage: .[0].stage,
  avg_duration_seconds: (map(.duration_seconds // 0) | add / length),
  avg_duration_minutes: ((map(.duration_seconds // 0) | add / length) / 60)
})' .claude/workflow-metrics.jsonl

# Average tokens by stage
jq -s 'group_by(.stage) | map({
  stage: .[0].stage,
  avg_input: (map(.tokens.input // 0) | add / length),
  avg_output: (map(.tokens.output // 0) | add / length),
  avg_cache_read: (map(.tokens.cache_read // 0) | add / length)
})' .claude/workflow-metrics.jsonl

# Total metrics across all stages
jq -s '{
  total_events: length,
  total_cost: (map(.cost_usd // 0) | add),
  total_duration_hours: ((map(.duration_seconds // 0) | add) / 3600),
  total_input_tokens: (map(.tokens.input // 0) | add),
  total_output_tokens: (map(.tokens.output // 0) | add)
}' .claude/workflow-metrics.jsonl
```

### Advanced Queries

```bash
# Most expensive stages (top 10)
jq 'select(.event=="stage_end")' .claude/workflow-metrics.jsonl | \
  jq -s 'sort_by(-.cost_usd) | .[0:10] | .[] | {stage, task, cost_usd, tokens}'

# Longest running stages (top 10)
jq 'select(.event=="stage_end")' .claude/workflow-metrics.jsonl | \
  jq -s 'sort_by(-.duration_seconds) | .[0:10] | .[] | {stage, task, duration_seconds}'

# Cost per minute by stage
jq 'select(.event=="stage_end" and .duration_seconds > 0)' .claude/workflow-metrics.jsonl | \
  jq -s 'map({
    stage,
    task,
    cost_per_minute: ((.cost_usd // 0) / (.duration_seconds / 60))
  })'

# Token efficiency (tokens per dollar)
jq 'select(.event=="stage_end" and .cost_usd > 0)' .claude/workflow-metrics.jsonl | \
  jq -s 'map({
    stage,
    task,
    tokens_per_dollar: ((.tokens.input + .tokens.output) / .cost_usd)
  })'

# Daily cost breakdown
jq 'select(.event=="stage_end")' .claude/workflow-metrics.jsonl | \
  jq -s 'group_by(.timestamp[:10]) | map({
    date: .[0].timestamp[:10],
    total_cost: (map(.cost_usd // 0) | add),
    stage_count: length
  })'
```

## Use Cases

### 1. Benchmarking Workflow Overhead

**Question:** Is the full workflow (analyst → planner → implementer → reviewer) worth the overhead vs fast-track?

**Approach:**
1. Run similar tasks through both paths
2. Compare total costs and duration
3. Evaluate quality differences

```bash
# Full workflow stages for a task
jq 'select(.task=="Implement feature X")' .claude/workflow-metrics.jsonl | \
  jq -s '{
    total_cost: (map(.cost_usd // 0) | add),
    total_duration: (map(.duration_seconds // 0) | add),
    stages: (map(.stage) | unique)
  }'

# Compare to fast-track equivalent
# (Note: Fast-track not tracked in Phase 1+2, but can estimate from single implementer stage)
```

### 2. Token Leak Detection

**Question:** Did a stage use abnormally high tokens? (Possible bug, infinite loop, etc.)

**Approach:**
1. Calculate average tokens per stage type
2. Flag outliers (e.g., 5x average)
3. Investigate transcript for root cause

```bash
# Find analyst stages with >50k input tokens
jq 'select(.stage=="analyst" and (.tokens.input // 0) > 50000)' .claude/workflow-metrics.jsonl | \
  jq -s '.[] | {task, tokens, cost_usd, session_id}'

# Compare to average
jq -s 'group_by(.stage) | map({
  stage: .[0].stage,
  avg_input: (map(.tokens.input // 0) | add / length),
  max_input: (map(.tokens.input // 0) | max),
  p95_input: (map(.tokens.input // 0) | sort | .[(length * 0.95 | floor)])
})' .claude/workflow-metrics.jsonl
```

### 3. Understanding Stage Distribution

**Question:** Which stages consume the most resources? Where should optimization focus?

**Approach:**
1. Aggregate by stage type
2. Visualize cost/time distribution
3. Identify optimization targets

```bash
# Cost distribution by stage
jq -s 'group_by(.stage) | map({
  stage: .[0].stage,
  total_cost: (map(.cost_usd // 0) | add),
  percentage: ((map(.cost_usd // 0) | add) / ([..[] | .cost_usd // 0] | add) * 100)
})' .claude/workflow-metrics.jsonl

# Duration distribution by stage
jq -s 'group_by(.stage) | map({
  stage: .[0].stage,
  total_hours: ((map(.duration_seconds // 0) | add) / 3600),
  percentage: ((map(.duration_seconds // 0) | add) / ([..[] | .duration_seconds // 0] | add) * 100)
})' .claude/workflow-metrics.jsonl
```

### 4. Model Usage Analysis

**Question:** Which models are being used most? Is auto-selection working well?

```bash
# Model distribution
jq 'select(.model != null)' .claude/workflow-metrics.jsonl | \
  jq -s 'group_by(.model) | map({
    model: .[0].model,
    count: length,
    total_cost: (map(.cost_usd // 0) | add),
    avg_cost: ((map(.cost_usd // 0) | add) / length)
  })'
```

## Current Limitations

### Known Issues

1. **Fast-track tasks not tracked** - Only subagent stages (analyst, planner, implementer, reviewer) are captured. When master handles a task directly (fast-track), no metrics are recorded.

2. **Concurrent subagents not tested** - Current implementation assumes sequential workflow. If multiple subagents run in parallel, start/end correlation may fail.

3. **Manual settings.json setup** - Users must manually configure hooks in their local settings.json (not tracked in git).

4. **Task identification imperfect** - Uses `$TASK` env var set by master, which may not always match beads task ID exactly. Human interpretation required for correlation.

### Edge Cases Handled

✅ Empty transcript (no API calls) → tokens = 0, cost = null
✅ Missing transcript file → graceful fallback to null
✅ Malformed JSON in transcript → parsing errors suppressed
✅ Unknown model → falls back to Sonnet 4 pricing
✅ Large token counts (>100k) → uses jq for arithmetic (no overflow)
✅ Session interruption → SubagentStop still fires, status = "interrupted"

## Troubleshooting

### Metrics not appearing in JSONL

**Check:**
1. Hooks configured in settings.json?
   ```bash
   cat ~/.claude/settings.json | jq '.hooks'
   ```

2. Hook scripts executable?
   ```bash
   ls -la .claude/hooks/metrics-*.sh
   ```

3. JSONL file writable?
   ```bash
   touch .claude/workflow-metrics.jsonl
   ```

4. Run a test task and check hook execution (add debug logging to scripts):
   ```bash
   echo "DEBUG: Hook fired at $(date)" >> /tmp/metrics-debug.log
   ```

### Token counts are all zero or null

**Possible causes:**
1. Agent didn't make any API calls (rare but possible)
2. Transcript file not found (check `agent_transcript_path` in hook input)
3. Transcript format changed (check transcript structure)

**Debug:**
```bash
# Find a recent agent_id
jq 'select(.event=="stage_end") | .agent_id' .claude/workflow-metrics.jsonl | tail -1

# Look for transcript path in Claude Code logs
# (Location varies by installation)
```

### BD comments not showing metrics

**Possible causes:**
1. Task ID doesn't contain a dot (metrics-end.sh only posts if $TASK looks like subtask format: `task-123.1`)
2. `bd` command not available in hook environment
3. Permission issues writing to beads

**Workaround:** BD comments are optional - JSONL is the primary data source. If BD comments fail, metrics are still captured in JSONL.

### Cost calculations seem wrong

**Verify:**
1. Model pricing table is up-to-date (see metrics-end.sh lines 90-103)
2. Token counts are accurate (check transcript manually)
3. Cache tokens being summed correctly (ephemeral_5m + ephemeral_1h)

**Recalculate manually:**
```bash
# Extract token and cost from JSONL
jq 'select(.session_id=="YOUR_SESSION") | {tokens, cost_usd, model}' .claude/workflow-metrics.jsonl

# Verify math:
# cost = (input_tokens * input_rate + output_tokens * output_rate + ...) / 1,000,000
```

---

## Related Documentation

- [Phase 1 Implementation](../../.claude/analysis/.claude-l0a.4-context.md) - Infrastructure and hook design
- [Phase 2 Implementation](../../.claude/analysis/.claude-6t5.1-context.md) - Transcript parsing and cost calculation
- [Testing Guide](TESTING.md) - Test cases and validation procedures
- [Lessons Learned](../lessons-learned.md) - Patterns and best practices

## Future Enhancements (Phase 3+)

Ideas for future work (not yet planned):

- Dashboard/visualization (web UI or terminal TUI)
- Automated alerts (e.g., "task exceeded budget")
- Integration with ccusage tool
- Cost projections based on historical data
- Recommendations engine ("This task type typically costs $X")
- Export to other formats (CSV, Prometheus, etc.)
- Real-time metrics (not just post-execution)
