# Claude-Golem Workflow Improvement: Discussion Summary

## Context

**Project:** [claude-golem](https://github.com/landovsky/claude-golem) — an AI software development framework for Claude Code with structured agent workflow (Master → Analyst → Planner → Implementer → Reviewer).

**Goal:** Design a process improvement system that enables iterative refinement of the agentic workflow through data collection and analysis.

---

## Approaches Considered and Rejected

### 1. Lessons-Learned Enhancement (Rejected)

Initial proposal: Extend the existing `lessons-learned.md` with structured observation, aggregation, and feedback loops.

**Why rejected:** Adds review burden. Requires manual effort to review process on top of reviewing work output. Lessons-learned files tend to grow but not get applied.

### 2. Introspection Stage (Challenged)

Proposal: Add stage to review agent "internal monologue" and record metrics.

**Problems identified:**
- [needs verification] Claude Code agents don't have accessible internal monologue — reasoning happens in context then vanishes
- "Explain why you did X" gets post-hoc rationalization, not actual causal chain
- Volume vs actionability: accumulated data often never gets analyzed
- Missing counterfactual: knowing *why* path A was chosen doesn't tell you if path B was better

**Counter-argument:** In agentic workflows, you debug reasoning (prompt engineering). Visibility into agent reasoning is raw material for improvement.

**Resolution:** Use hypothesis-driven collection — define what you need to learn, collect only data that proves/disproves it.

---

## Final Direction: Leverage Existing OTel Telemetry

Claude Code already emits comprehensive OpenTelemetry metrics and events. No need to add custom introspection.

### Three Goals Mapped to Available Data

| Goal | OTel Event/Metric | Key Attributes |
|------|-------------------|----------------|
| **Catch errors** | `claude_code.api_error`, `tool_result` (success=false) | `error`, `status_code`, `tool_name` |
| **Detect inefficient behavior** | `tool_result` | `tool_name`, `tool_parameters.bash_command`, `error` |
| **Monitor token usage/spikes** | `claude_code.token.usage`, `claude_code.api_request` | `type`, `input_tokens`, `output_tokens`, `cache_read_tokens` |

---

## Proposed Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Claude Code Session                          │
│                   (CLAUDE_CODE_ENABLE_TELEMETRY=1)               │
└──────────────────────────┬──────────────────────────────────────┘
                           │ OTel events + metrics
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Local Collector                               │
│              (writes to ~/.claude/telemetry/)                    │
│                                                                  │
│   Option A: Console exporter → JSONL files                       │
│   Option B: Local OTLP collector → SQLite/DuckDB                 │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    /analyze command                              │
│         Queries local store, surfaces actionable signals         │
└─────────────────────────────────────────────────────────────────┘
```

---

## Storage Options

### Option A: JSONL Files (Simplest)

```bash
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=console
export OTEL_LOGS_EXPORTER=console
claude 2>> ~/.claude/telemetry/$(date +%Y-%m-%d).jsonl
```

**Pros:** Zero dependencies, git-backable, grep-able
**Cons:** No querying, manual parsing

### Option B: Local OTLP → SQLite/DuckDB

Run lightweight collector writing to SQLite. DuckDB can query JSONL directly.

**Pros:** Queryable, aggregations, can sync to remote later
**Cons:** Extra process to run

### Option C: Hybrid (Recommended)

Start with JSONL. Build `/analyze` to parse JSONL. Add DuckDB when volume justifies — it reads JSONL natively.

---

## Actionable Signals to Extract

### 1. Errors (Immediate Alerts)

```sql
-- Failed tool executions
SELECT timestamp, tool_name, error, tool_parameters
FROM tool_result_events
WHERE success = 'false';

-- API errors
SELECT timestamp, error, status_code, attempt
FROM api_error_events;
```

**Patterns to detect:**
- Repeated `status_code=429` → Rate limiting
- Bash + "permission denied" → Resource access issue
- Read + "not found" → Agent looking in wrong place

### 2. Inefficient Behavior (Batch Analysis)

```sql
-- Bash commands that failed
SELECT
  tool_parameters->>'bash_command' as command,
  error,
  COUNT(*) as occurrences
FROM tool_result_events
WHERE tool_name = 'Bash' AND success = 'false'
GROUP BY command, error;

-- Tools with high failure rates
SELECT
  tool_name,
  COUNT(*) FILTER (WHERE success = 'false') as failures,
  COUNT(*) as total
FROM tool_result_events
GROUP BY tool_name
HAVING COUNT(*) > 5;
```

**Patterns to detect:**
- Same bash command failing repeatedly → Agent prompt needs syntax example
- High fail rate on specific tool → Check agent instructions
- Long `duration_ms` on Read → Agent reading too many files

### 3. Token Spikes (Cost Control)

```sql
-- Sessions with unusual consumption
SELECT
  session_id,
  SUM(input_tokens) as total_input,
  SUM(output_tokens) as total_output,
  SUM(cache_read_tokens) as cache_hits
FROM api_request_events
GROUP BY session_id;

-- Cache miss detection
SELECT
  session_id,
  input_tokens,
  cache_read_tokens,
  100.0 * cache_read_tokens / NULLIF(input_tokens, 0) as cache_hit_rate
FROM api_request_events
WHERE input_tokens > 10000;
```

**Patterns to detect:**
- Low cache hit rate → Agent not reusing context efficiently
- Spike in `input_tokens` mid-session → Re-reading entire codebase
- High `output_tokens` with low code changes → Verbose, tighten prompt

---

## Proposed `/analyze` Command

```markdown
# commands/analyze.md

## Purpose
Surface actionable signals from telemetry data.

## Input
Reads from ~/.claude/telemetry/*.jsonl

## Reports

### Errors (last 24h)
- List failed tool executions with context
- Group by error type
- Flag if same error occurred 3+ times

### Efficiency (last 7 days)
- Tools with >20% failure rate
- Bash commands that failed (show command + error)
- Sessions with >50% token increase vs average

### Token Trends
- Daily token usage (input/output/cache)
- Top 5 sessions by cost
- Cache hit rate trend

## Output
File: analysis/telemetry-report-{date}.md
Console: Summary with counts and top issues
```

---

## Minimal Setup to Start

```bash
# Add to shell profile
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_LOGS_EXPORTER=console
export OTEL_METRICS_EXPORTER=console

# Create directory
mkdir -p ~/.claude/telemetry

# Wrapper script
#!/bin/bash
claude "$@" 2>> ~/.claude/telemetry/$(date +%Y-%m-%d).jsonl
```

---

## Next Steps

1. Enable telemetry and start collecting JSONL data
2. Build minimal `/analyze` command — start with error detection (grep for `"success":"false"`)
3. Add token analysis after ~1 week of data
4. Consider DuckDB when querying JSONL becomes slow

---

## Key Insight

Don't add introspection to agents — use the telemetry already being emitted. The improvement loop becomes:

```
Collect OTel data → /analyze surfaces patterns → Update agent prompts → Measure if pattern frequency decreases
```

---

## Reference

- [Claude Code Monitoring Docs](https://code.claude.com/docs/en/monitoring-usage)
- [Claude-Golem Repository](https://github.com/landovsky/claude-golem)
