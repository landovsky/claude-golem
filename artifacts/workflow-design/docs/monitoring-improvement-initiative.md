# Monitoring & Improvement Initiative

**Date**: 2026-02-01
**Status**: Analysis Phase
**Project**: Claude-Golem Workflow System

---

## Executive Summary

This document consolidates the rationale and requirements for a comprehensive **Monitoring & Improvement** initiative that combines:

1. **Token usage tracking** (cost optimization)
2. **Error & inefficiency detection** (reliability improvement)
3. **Quality metrics** (reviewer findings, issue trends)
4. **Hypothesis-driven experimentation** (workflow optimization)

The goal is not just to collect data, but to create a **closed feedback loop** where observations drive improvements, and measurements validate their effectiveness.

---

## Problem Statement

### Current State

The workflow system operates with **limited visibility**:

| Area | Current State | Impact |
|------|---------------|--------|
| **Token costs** | Daily aggregates only (stats-cache.json) | ❌ Can't attribute costs to workflows/stages |
| **Errors** | Visible in session logs, not analyzed | ❌ Patterns go undetected |
| **Quality** | Reviewer metrics collected (`.claude-metrics`) | ⚠️ Data exists but no trend analysis |
| **Workflow efficiency** | No loop/retry tracking | ❌ Can't identify inefficient workflows |
| **Improvement validation** | No A/B testing or hypothesis framework | ❌ Changes made on intuition, not data |

### What We Need

A **unified monitoring system** that:
- ✅ Attributes token costs to workflows and stages
- ✅ Detects error patterns and inefficiencies automatically
- ✅ Tracks quality trends over time (reviewer findings)
- ✅ Enables hypothesis testing for workflow improvements
- ✅ Provides actionable insights, not just raw data

---

## Vision: The Improvement Loop

```
┌─────────────────────────────────────────────────────────────────┐
│                    MEASUREMENT LAYER                             │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Token Usage  │  │ Error Rates  │  │ Quality      │          │
│  │ (OTel)       │  │ (OTel)       │  │ (.claude-    │          │
│  │              │  │              │  │  metrics)    │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ANALYSIS LAYER                                │
│                                                                  │
│  • Aggregate metrics across workflows                            │
│  • Detect patterns (repeated errors, cost spikes)                │
│  • Track trends (quality improving/degrading?)                   │
│  • Surface anomalies (outlier workflows)                         │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    INSIGHTS LAYER                                │
│                                                                  │
│  • Dashboards: cost breakdown, error patterns, quality trends    │
│  • Alerts: cost threshold exceeded, error rate spike             │
│  • Reports: weekly summaries, workflow comparisons               │
│  • Recommendations: which workflows to optimize                  │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    EXPERIMENTATION LAYER                         │
│                                                                  │
│  Hypothesis: "Analyst stage uses too many tokens"                │
│  Intervention: Add file count limit to analyst prompt            │
│  Measurement: Compare avg tokens before/after change             │
│  Validation: Did it reduce cost without increasing errors?       │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
                    [Workflow Updates]
                           │
                           └──────────┐
                                      │
                                      ▼
                            [Continuous Monitoring]
```

---

## Metrics to Track

### 1. Token Usage & Cost (OTel)

**Purpose**: Cost optimization, budget forecasting, model selection validation

**Metrics**:
- `claude_code.token.usage` - by type (input/output/cacheRead/cacheCreation)
- `claude_code.cost.usage` - per API request
- `claude_code.api_request` events - full per-request breakdown

**Dimensions**:
- Workflow ID (e.g., `.claude-4nq`)
- Stage (analyze/plan/implement/review)
- Task ID (e.g., `.claude-4nq.1-analyze`)
- Agent (analyst/planner/implementer/reviewer)
- Model (opus/sonnet)

**Queries**:
```sql
-- Total cost per workflow
SELECT workflow_id, SUM(cost_usd) as total_cost
FROM otel_api_request_events
GROUP BY workflow_id
ORDER BY total_cost DESC;

-- Cost breakdown by stage
SELECT stage, AVG(cost_usd) as avg_cost, COUNT(*) as workflows
FROM otel_api_request_events
GROUP BY stage;

-- Model cost efficiency (Opus vs Sonnet)
SELECT model, stage, SUM(cost_usd) as total_cost, SUM(input_tokens + output_tokens) as total_tokens
FROM otel_api_request_events
GROUP BY model, stage;

-- Cache effectiveness
SELECT
  workflow_id,
  SUM(cache_read_tokens) / NULLIF(SUM(input_tokens), 0) * 100 as cache_hit_rate_pct
FROM otel_api_request_events
GROUP BY workflow_id
HAVING SUM(input_tokens) > 10000
ORDER BY cache_hit_rate_pct ASC;  -- Find low cache workflows
```

**Actionable Insights**:
- Which stages cost most? (consider model downgrade)
- Which workflows have low cache hit rates? (improve context reuse)
- Is fast-track cheaper than full workflow? (routing optimization)

---

### 2. Errors & Failures (OTel)

**Purpose**: Reliability improvement, root cause analysis

**Events**:
- `claude_code.api_error` - API failures (rate limits, timeouts)
- `claude_code.tool_result` (success=false) - Tool execution failures

**Dimensions**:
- Error type/message
- Tool name (Bash, Read, Write, Edit, etc.)
- Status code (429=rate limit, 500=server error)
- Stage/agent context

**Queries**:
```sql
-- Most common errors
SELECT error, COUNT(*) as occurrences
FROM otel_api_error_events
GROUP BY error
ORDER BY occurrences DESC
LIMIT 10;

-- Failed tool executions by type
SELECT tool_name, COUNT(*) as failures
FROM otel_tool_result_events
WHERE success = 'false'
GROUP BY tool_name
ORDER BY failures DESC;

-- Failed Bash commands (most valuable for debugging)
SELECT
  tool_parameters->>'bash_command' as command,
  error,
  COUNT(*) as occurrences
FROM otel_tool_result_events
WHERE tool_name = 'Bash' AND success = 'false'
GROUP BY command, error
HAVING COUNT(*) >= 3  -- Repeated failures only
ORDER BY occurrences DESC;

-- Error rate by stage
SELECT
  stage,
  COUNT(*) FILTER (WHERE success = 'false') * 100.0 / COUNT(*) as error_rate_pct
FROM otel_tool_result_events
WHERE stage IS NOT NULL
GROUP BY stage;
```

**Actionable Insights**:
- Repeated bash failures → add syntax examples to agent prompts
- High Read tool failures → agent looking in wrong paths (fix instructions)
- Rate limit errors (429) → implement backoff or reduce concurrency

---

### 3. Workflow Efficiency (OTel + Custom)

**Purpose**: Detect loops, retries, wasted effort

**Metrics to Add**:
- **Loop count**: How many times did an agent retry the same operation?
- **Rework count**: Did implementer have to redo work after reviewer feedback?
- **Tool call density**: Tools per API request (high = thrashing)
- **Session duration**: Time from start to completion per stage

**Implementation**:

**Via OTel (already available)**:
```sql
-- Tool calls per workflow (high = potential thrashing)
SELECT
  workflow_id,
  COUNT(*) as tool_calls,
  COUNT(DISTINCT tool_name) as unique_tools,
  AVG(duration_ms) as avg_tool_duration_ms
FROM otel_tool_result_events
GROUP BY workflow_id
ORDER BY tool_calls DESC;

-- Workflows with high API request count (possible loops)
SELECT
  workflow_id,
  stage,
  COUNT(*) as api_requests,
  SUM(cost_usd) as total_cost
FROM otel_api_request_events
GROUP BY workflow_id, stage
HAVING COUNT(*) > 10  -- Flag stages with >10 API calls
ORDER BY api_requests DESC;
```

**Via Custom Instrumentation** (need to add):
- **Rework flag**: Reviewer marks issue as "requires implementation rework"
  - Storage: `.claude-metrics` JSON with `rework: true/false`
  - Query: Count workflows with rework vs. clean pass
- **Retry events**: Agent explicitly retries after failure
  - Emit custom OTel event: `claude_golem.retry` with `reason`, `attempt_number`

**Actionable Insights**:
- High loop count in analyst → prompt too vague, agent exploring aimlessly
- Frequent rework after review → implementer misunderstands specs (improve planner clarity)
- Long tool durations → agents waiting on slow operations (optimize tooling)

---

### 4. Quality Metrics (Reviewer Findings)

**Purpose**: Track improvement over time, identify persistent problem areas

**Current Implementation**: `.claude-metrics` task with JSON comments

**Schema** (already in use):
```json
{
  "v": 1,
  "ts": "2026-01-31T20:49:38Z",
  "task": ".claude-gvl.4",
  "parent": ".claude-gvl",
  "severity": {
    "critical": 0,
    "major": 0,
    "minor": 1
  },
  "categories": {
    "documentation": 1
  },
  "issues": [
    {
      "severity": "minor",
      "category": "documentation",
      "file": "/workspace/agents/reviewer.md",
      "line": 300,
      "summary": "Size limit error handling guidance is vague"
    }
  ]
}
```

**Queries Needed**:
```sql
-- Quality trend over time
SELECT
  DATE(ts) as date,
  SUM(severity.critical) as critical_issues,
  SUM(severity.major) as major_issues,
  SUM(severity.minor) as minor_issues
FROM claude_metrics
GROUP BY DATE(ts)
ORDER BY date;

-- Most common issue categories
SELECT
  category,
  COUNT(*) as occurrences,
  AVG(CASE severity WHEN 'critical' THEN 3 WHEN 'major' THEN 2 WHEN 'minor' THEN 1 ELSE 0 END) as avg_severity
FROM claude_metrics, UNNEST(issues) as issue
GROUP BY category
ORDER BY occurrences DESC;

-- Workflows with cleanest reviews (benchmarks)
SELECT
  parent as workflow_id,
  SUM(severity.critical + severity.major + severity.minor) as total_issues
FROM claude_metrics
GROUP BY parent
ORDER BY total_issues ASC
LIMIT 10;

-- Repeat offenders (files with most issues)
SELECT
  issue.file,
  COUNT(*) as issue_count,
  ARRAY_AGG(DISTINCT issue.category) as categories
FROM claude_metrics, UNNEST(issues) as issue
GROUP BY issue.file
ORDER BY issue_count DESC;
```

**Actionable Insights**:
- Trend shows increasing issues → workflow degrading, investigate recent changes
- Specific category dominant (e.g., "testing") → add testing guidance to implementer
- Certain files always flagged → may need refactoring or better templates
- Clean workflows → identify what made them successful (use as examples)

---

### 5. Workflow Path Metrics

**Purpose**: Validate routing decisions (fast-track vs full workflow)

**Dimensions**:
- Workflow path: `fast-track` vs `full`
- Complexity assessment: `simple` vs `complex` (from master)
- Specification completeness: `complete` vs `incomplete` (from master)

**Metrics to Track**:
```sql
-- Cost by workflow path
SELECT
  workflow_path,
  COUNT(*) as workflow_count,
  AVG(total_cost) as avg_cost,
  AVG(duration_seconds) as avg_duration_sec
FROM workflow_summary
GROUP BY workflow_path;

-- Success rate by path (custom metric: did it complete without errors?)
SELECT
  workflow_path,
  COUNT(*) FILTER (WHERE error_count = 0) * 100.0 / COUNT(*) as success_rate_pct
FROM workflow_summary
GROUP BY workflow_path;

-- Was complexity assessment accurate?
-- (Did "simple" workflows actually complete faster/cheaper?)
SELECT
  complexity_assessment,
  AVG(total_cost) as avg_cost,
  AVG(duration_seconds) as avg_duration_sec,
  AVG(error_count) as avg_errors
FROM workflow_summary
GROUP BY complexity_assessment;
```

**Actionable Insights**:
- Fast-track has lower success rate → tighten criteria for fast-track eligibility
- "Simple" workflows cost as much as "complex" → master's assessment is inaccurate
- Full workflow always cheaper than fast-track → routing logic is backwards

---

## Hypothesis Testing Framework

### Purpose

Enable **data-driven experimentation** on workflow improvements.

### Process

1. **Formulate Hypothesis**
   - Example: "Reducing analyst's file read limit from 50 to 20 will reduce token usage by 30% without increasing errors"

2. **Define Metrics**
   - Primary: `AVG(tokens) WHERE stage='analyze'`
   - Secondary: `error_rate WHERE stage='analyze'`
   - Guardrail: `rework_rate` (did reviewer flag issues?)

3. **Implement Change**
   - Modify `agents/analyst.md` with new file limit
   - Tag workflows with experiment ID: `OTEL_RESOURCE_ATTRIBUTES="experiment_id=analyst-file-limit-v2"`

4. **Collect Data**
   - Run 10-20 workflows with new configuration
   - Query metrics for `experiment_id=analyst-file-limit-v2`

5. **Analyze Results**
   ```sql
   -- Compare experiment vs. baseline
   SELECT
     experiment_id,
     AVG(input_tokens) as avg_input_tokens,
     AVG(output_tokens) as avg_output_tokens,
     COUNT(*) FILTER (WHERE error_count > 0) * 100.0 / COUNT(*) as error_rate_pct
   FROM workflow_summary
   WHERE stage = 'analyze' AND experiment_id IN ('baseline', 'analyst-file-limit-v2')
   GROUP BY experiment_id;
   ```

6. **Decision**
   - ✅ If hypothesis confirmed: keep change, update baseline
   - ❌ If hypothesis rejected: revert, document learnings
   - ⚠️ If inconclusive: extend experiment or refine hypothesis

### Experiment Ideas

| Hypothesis | Metric to Track | Expected Impact |
|------------|-----------------|-----------------|
| **Analyst reads too many files** | Tokens/stage, error rate | -30% tokens, +0% errors |
| **Planner should use Opus instead of Sonnet** | Plan quality (reviewer issues), cost | -20% rework, +50% cost |
| **Implementer should create smaller commits** | Reviewer issues, commits/workflow | -15% issues, +2 commits/wf |
| **Reviewer should check tests first** | Review duration, critical issues found | -25% duration, +10% critical found |
| **Fast-track threshold too aggressive** | Fast-track success rate | +15% success rate |

---

## Architecture Proposal

### Tech Stack

**Collection**: Claude Code OpenTelemetry (native)
**Transport**: OTLP (OpenTelemetry Protocol)
**Storage**: ClickHouse (events + metrics) + `.claude-metrics` (quality data)
**Analysis**: DuckDB (for ad-hoc JSONL queries), ClickHouse (for structured queries)
**Visualization**: Grafana (dashboards), custom scripts (reports)
**Alerting**: Prometheus Alertmanager (cost/error thresholds)

### Data Flow

```
┌──────────────────────────────────────────────────────────────────┐
│  WORKFLOW EXECUTION (Claude Code)                                 │
│  - Master → Analyst → Planner → Implementer → Reviewer            │
│  - Each stage sets OTEL_RESOURCE_ATTRIBUTES                       │
│    (workflow_id, stage, task_id, agent, experiment_id)            │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ├─────────────────────────────────────────┐
                         │                                         │
                         ▼                                         ▼
┌─────────────────────────────────────┐  ┌───────────────────────────┐
│  OTel Collector                      │  │  Reviewer (agent)         │
│  - Receives metrics/events via OTLP  │  │  - Posts quality JSON     │
│  - Exports to ClickHouse             │  │    to .claude-metrics     │
└────────────────────────┬─────────────┘  └─────────────┬─────────────┘
                         │                              │
                         ▼                              ▼
┌─────────────────────────────────────┐  ┌───────────────────────────┐
│  ClickHouse Database                 │  │  .claude-metrics (Beads)  │
│  - otel_api_request_events           │  │  - JSON comments          │
│  - otel_tool_result_events           │  │  - Queryable via bd CLI   │
│  - otel_api_error_events             │  │                           │
│  - Materialized views for aggregates │  │                           │
└────────────────────────┬─────────────┘  └─────────────┬─────────────┘
                         │                              │
                         └──────────────┬───────────────┘
                                        │
                                        ▼
┌──────────────────────────────────────────────────────────────────┐
│  ANALYSIS & REPORTING                                             │
│                                                                   │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────────┐ │
│  │ Grafana         │  │ /analyze        │  │ Weekly Report    │ │
│  │ Dashboards      │  │ Command         │  │ Script           │ │
│  │                 │  │                 │  │                  │ │
│  │ - Cost trends   │  │ - Error summary │  │ - Email digest   │ │
│  │ - Error rates   │  │ - Top issues    │  │ - Quality trends │ │
│  │ - Quality chart │  │ - Recommendations│  │ - Cost summary   │ │
│  └─────────────────┘  └─────────────────┘  └──────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

### Storage Locations

| Data Type | Storage | Format | Queryable? |
|-----------|---------|--------|------------|
| **Token usage** | ClickHouse | OTel events/metrics | ✅ SQL |
| **Errors** | ClickHouse | OTel events | ✅ SQL |
| **Tool results** | ClickHouse | OTel events | ✅ SQL |
| **Quality metrics** | `.claude-metrics` (Beads) | JSON comments | ⚠️ Manual (bd comments) |
| **Session logs** | `~/.claude/history.jsonl` | JSONL | ⚠️ DuckDB or grep |
| **Daily aggregates** | `~/.claude/stats-cache.json` | JSON | ⚠️ jq/Python |

**Integration Opportunity**: Export `.claude-metrics` JSON to ClickHouse for unified querying.

---

## Implementation Phases

### Phase 0: Analysis (Current Phase)

**Goal**: Finalize requirements and architecture

**Tasks**:
- ✅ Read existing process improvement rationale
- ✅ Review OTel capabilities and ccusage fit
- ✅ Define metrics to track
- ✅ Design hypothesis testing framework
- 🔲 Validate technical feasibility (OTel attribute propagation)
- 🔲 Get stakeholder approval on scope

**Duration**: 1 week
**Output**: This document (finalized) + architectural decision record

---

### Phase 1: Foundation (Weeks 1-2)

**Goal**: Set up telemetry collection infrastructure

**Tasks**:
1. Deploy OTel Collector + ClickHouse via Docker Compose
2. Configure Claude Code to export telemetry
3. Validate data flow (metrics/events appearing in ClickHouse)
4. Create ClickHouse schema for OTel events
5. Test custom OTEL_RESOURCE_ATTRIBUTES injection
6. Document setup process

**Success Criteria**:
- ✅ Run one workflow end-to-end
- ✅ All stages' token usage visible in ClickHouse
- ✅ Custom attributes (workflow_id, stage, task_id) appear correctly

**Risk**: OTel attribute propagation to subagents may not work as expected
**Mitigation**: Test early, adjust instrumentation approach if needed

---

### Phase 2: Workflow Instrumentation (Weeks 3-4)

**Goal**: Automatic tracking for all workflows with stage granularity

**Tasks**:
1. Modify `commands/develop.md` to generate workflow_id
2. Update `agents/master.md` to set OTEL_RESOURCE_ATTRIBUTES before each Task invocation
3. Create `scripts/otel-set-stage.sh` helper for updating attributes
4. Add workflow_path (fast-track/full) and complexity tracking
5. Validate end-to-end for multiple workflows
6. Document instrumentation patterns

**Success Criteria**:
- ✅ 100% of workflows automatically tracked
- ✅ Per-stage cost attribution working
- ✅ No manual intervention required

**Risk**: Bash environment variable changes between subagent invocations
**Mitigation**: Test environment variable persistence across Task tool calls

---

### Phase 3: Quality Data Integration (Week 5)

**Goal**: Unify quality metrics with telemetry data

**Tasks**:
1. Create ClickHouse schema for quality metrics
2. Build `scripts/metrics-to-clickhouse.sh` to sync `.claude-metrics` JSON
3. Create unified views joining OTel + quality data
4. Add quality metrics to workflow_summary view
5. Test quality trend queries

**Success Criteria**:
- ✅ Reviewer findings queryable in ClickHouse
- ✅ Can correlate quality with cost/errors in single query
- ✅ Quality trends visible over time

---

### Phase 4: Analysis & Dashboards (Week 6)

**Goal**: Make data actionable through visualization and alerts

**Tasks**:
1. **Grafana Dashboards**:
   - Workflow cost breakdown (by stage, agent, model)
   - Error rate trends (by stage, tool)
   - Quality trends (severity over time, category distribution)
   - Workflow path comparison (fast-track vs full)

2. **Custom Reports**:
   - Weekly summary email (costs, top errors, quality trends)
   - Workflow comparison report (compare two workflow IDs)
   - Optimization recommendations (high-cost stages, low cache hit rates)

3. **Alerts**:
   - Cost threshold exceeded (workflow > $X)
   - Error rate spike (stage error rate > Y%)
   - Quality regression (critical issues > Z per week)

**Success Criteria**:
- ✅ Stakeholders can self-serve data via dashboards
- ✅ Automated weekly reports sent
- ✅ Alerts catch anomalies within 1 hour

---

### Phase 5: Hypothesis Testing (Week 7-8)

**Goal**: Enable data-driven workflow optimization

**Tasks**:
1. Document experiment process (hypothesis template)
2. Implement experiment tagging (experiment_id in OTEL_RESOURCE_ATTRIBUTES)
3. Create experiment comparison queries
4. Run first experiment (e.g., analyst file limit)
5. Document experiment results and decision
6. Build experiment tracking dashboard

**Success Criteria**:
- ✅ Complete one full experiment cycle (hypothesis → data → decision)
- ✅ Experiment framework documented and reusable
- ✅ Team trained on hypothesis testing process

---

### Phase 6: Continuous Improvement (Ongoing)

**Goal**: Establish rhythm for monitoring and optimization

**Practices**:
1. **Weekly review**: Check dashboards, review alerts, discuss trends
2. **Monthly experiments**: Run 1-2 optimization experiments per month
3. **Quarterly deep dives**: Analyze long-term trends, major optimizations
4. **Documentation**: Update workflow guides based on learnings

**Metrics to Track**:
- Cost per workflow (trending down over time)
- Error rate (trending down)
- Quality (critical issues trending down)
- Experiment success rate (% of hypotheses confirmed)

---

## Success Metrics

### Short-term (3 months)

| Metric | Baseline | Target | Measurement |
|--------|----------|--------|-------------|
| **Cost visibility** | Daily aggregates only | 100% workflows attributed | ClickHouse query |
| **Error detection** | Manual review | Automated alerts | Alert count |
| **Quality tracking** | Manual inspection | Automated trend charts | Grafana dashboard |
| **Experiments run** | 0 | 3 completed | Experiment log |

### Long-term (6-12 months)

| Metric | Baseline | Target | Measurement |
|--------|----------|--------|-------------|
| **Cost reduction** | $4,050/month | -20% ($3,240/month) | Monthly spend |
| **Error rate** | Unknown | <5% per stage | OTel query |
| **Quality improvement** | Unknown | -30% critical issues | .claude-metrics query |
| **Workflow efficiency** | Unknown | -15% avg duration | OTel duration_ms |
| **Team confidence** | Subjective | 80% decisions data-backed | Survey |

---

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| **OTel attribute propagation fails** | 🔴 HIGH | 🟡 MEDIUM | Test early (Phase 1), fallback to master-level tracking |
| **ClickHouse complexity** | 🟡 MEDIUM | 🟡 MEDIUM | Use managed ClickHouse Cloud, extensive documentation |
| **Data volume overwhelming** | 🟡 MEDIUM | 🟢 LOW | Start with aggregates, use ClickHouse TTL for raw events |
| **Team doesn't use dashboards** | 🟡 MEDIUM | 🟡 MEDIUM | Weekly review ritual, tie to decision-making |
| **Experiments don't yield insights** | 🟡 MEDIUM | 🟢 LOW | Start with high-confidence hypotheses, iterate |
| **Infrastructure costs** | 🟢 LOW | 🟢 LOW | Self-hosted ClickHouse, minimal resource usage |

---

## Open Questions

### Technical

1. **Does OTEL_RESOURCE_ATTRIBUTES propagate to subagents?**
   - Test: Set in master, check if analyst API calls inherit it
   - If NO: Set in each agent's Task invocation wrapper

2. **Can we correlate OTel session_id with Beads workflow_id?**
   - Need: Mapping table or include both in OTEL_RESOURCE_ATTRIBUTES

3. **What's the cardinality limit for OTEL_RESOURCE_ATTRIBUTES?**
   - W3C Baggage spec has limits, need to test with 10+ attributes

4. **Should we use ClickHouse Cloud or self-hosted?**
   - Trade-off: Managed vs. control/cost
   - Recommendation: Start self-hosted, migrate if volume justifies

### Process

1. **Who reviews dashboards weekly?**
   - Assign: workflow owner + team lead

2. **What's the threshold for cost alerts?**
   - Propose: Workflow > $5, Stage > $2, Daily > $150

3. **How do we prioritize experiments?**
   - Criteria: Expected impact × ease of implementation

4. **Should we track individual developer metrics?**
   - Privacy consideration: Track workflow-level only, not user-level

---

## Dependencies

### External

- ✅ Claude Code OpenTelemetry support (already available)
- ✅ ClickHouse (open-source, well-documented)
- ✅ Grafana (open-source, well-documented)

### Internal

- 🔲 `.claude-metrics` format stabilized (currently v1, may evolve)
- 🔲 Workflow IDs consistent (need naming convention)
- 🔲 Stage naming standardized (analyze/plan/implement/review)

---

## Related Work

### Existing Implementations

- **`.claude-gvl`**: Reviewer severity tracking (✓ completed)
- **`.claude-metrics`**: Quality data storage (✓ active)
- **`stats-cache.json`**: Daily token aggregates (✓ existing)
- **`history.jsonl`**: Session logs (✓ existing)

### Blocked Tasks

- **`.claude-1yt`**: Collect Claude usage data via ccusage
  - Decision: Use OTel as primary, ccusage as complementary
- **`.claude-metrics`**: Review metrics tracking
  - Decision: Integrate with ClickHouse for unified querying

---

## Next Steps

1. **Finalize this document** (stakeholder review, iterate)
2. **Create architectural decision record** (ADR) for OTel + ClickHouse choice
3. **Validate technical feasibility** (OTel attribute propagation test)
4. **Create Phase 1 implementation plan** (detailed task breakdown)
5. **Get approval to proceed** with Phase 1 (infrastructure setup)

---

## Appendix: Example Queries

### Cost Analysis

```sql
-- Top 10 most expensive workflows
SELECT
  workflow_id,
  SUM(cost_usd) as total_cost,
  SUM(input_tokens + output_tokens) as total_tokens,
  COUNT(*) as api_requests
FROM otel_api_request_events
GROUP BY workflow_id
ORDER BY total_cost DESC
LIMIT 10;

-- Cost per stage (average across all workflows)
SELECT
  stage,
  COUNT(DISTINCT workflow_id) as workflow_count,
  AVG(cost_usd) as avg_cost_per_request,
  SUM(cost_usd) as total_cost
FROM otel_api_request_events
WHERE stage IS NOT NULL
GROUP BY stage
ORDER BY total_cost DESC;

-- Daily cost trend
SELECT
  DATE(timestamp) as date,
  SUM(cost_usd) as daily_cost,
  COUNT(DISTINCT workflow_id) as workflows_run
FROM otel_api_request_events
GROUP BY DATE(timestamp)
ORDER BY date;
```

### Error Analysis

```sql
-- Error hotspots (which stages fail most?)
SELECT
  stage,
  tool_name,
  COUNT(*) as failure_count,
  ARRAY_AGG(DISTINCT error ORDER BY error) as error_types
FROM otel_tool_result_events
WHERE success = 'false' AND stage IS NOT NULL
GROUP BY stage, tool_name
ORDER BY failure_count DESC;

-- Workflows with most errors
SELECT
  workflow_id,
  COUNT(*) FILTER (WHERE success = 'false') as error_count,
  COUNT(*) as total_tool_calls,
  COUNT(*) FILTER (WHERE success = 'false') * 100.0 / COUNT(*) as error_rate_pct
FROM otel_tool_result_events
GROUP BY workflow_id
HAVING COUNT(*) FILTER (WHERE success = 'false') > 0
ORDER BY error_count DESC;
```

### Quality Analysis

```sql
-- Quality trend (requires .claude-metrics imported to ClickHouse)
SELECT
  toStartOfWeek(ts) as week,
  SUM(severity.critical) as critical,
  SUM(severity.major) as major,
  SUM(severity.minor) as minor,
  COUNT(DISTINCT parent) as workflows_reviewed
FROM claude_metrics
GROUP BY week
ORDER BY week;

-- Problem categories over time
SELECT
  category,
  COUNT(*) as total_issues,
  COUNT(*) FILTER (WHERE severity = 'critical') as critical_count
FROM (
  SELECT parent, ts, arrayJoin(issues) as issue
  FROM claude_metrics
)
GROUP BY issue.category
ORDER BY total_issues DESC;
```

### Hypothesis Testing

```sql
-- Compare two experiment groups
SELECT
  experiment_id,
  COUNT(DISTINCT workflow_id) as workflows,
  AVG(total_cost) as avg_cost,
  AVG(total_tokens) as avg_tokens,
  AVG(duration_seconds) as avg_duration_sec,
  AVG(error_count) as avg_errors
FROM (
  SELECT
    experiment_id,
    workflow_id,
    SUM(cost_usd) as total_cost,
    SUM(input_tokens + output_tokens) as total_tokens,
    MAX(timestamp) - MIN(timestamp) as duration_seconds,
    COUNT(*) FILTER (WHERE success = 'false') as error_count
  FROM otel_api_request_events
  WHERE experiment_id IN ('baseline', 'analyst-file-limit-v2')
  GROUP BY experiment_id, workflow_id
)
GROUP BY experiment_id;
```

---

**Document Status**: Draft for Review
**Next Review**: After stakeholder feedback
**Owner**: TBD
**Last Updated**: 2026-02-01
