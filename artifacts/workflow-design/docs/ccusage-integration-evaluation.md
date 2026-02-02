# ccusage Integration Evaluation

**Date**: 2026-02-01
**Objective**: Track token usage per workflow invocation with per-stage granularity
**Project**: Claude Code workflow orchestration system (master → analyst → planner → implementer → reviewer)

---

## Executive Summary

**Verdict**: ⚠️ **Partial Fit - Custom Extension Required**

ccusage provides excellent **post-session analytics** but lacks **real-time per-workflow tracking**. Your workflow system needs granular, structured metrics that ccusage doesn't natively provide. However, the underlying architecture (JSONL data files + Beads task tracking) creates a strong foundation for a hybrid approach.

**Recommended Path**: Extend workflow system with custom instrumentation, leverage ccusage for reporting/visualization.

---

## 1. Gap Analysis

### What ccusage Provides ✅

| Feature | Status | Value for Project |
|---------|--------|-------------------|
| Daily token aggregation | ✅ Native | Good for overall cost tracking |
| Monthly reports | ✅ Native | Budget planning |
| Session-level breakdown | ✅ Native | Per-conversation analysis |
| Model-specific costs | ✅ Native | Critical (Opus vs Sonnet) |
| Cache token metrics | ✅ Native | High value - already seeing 189M cache reads |
| JSON export | ✅ Native | Enables custom analysis |
| 5-hour billing blocks | ✅ Native | Aligns with Claude's pricing model |
| Statusline integration | ✅ Beta | Real-time display in terminal |

### What's Missing ❌

| Requirement | ccusage Support | Impact |
|-------------|-----------------|--------|
| **Per-workflow invocation tracking** | ❌ None | **CRITICAL** - Can't measure task-level costs |
| **Per-stage granularity** | ❌ None | **CRITICAL** - Can't see analyst vs implementer costs |
| **Task ID correlation** | ❌ None | **HIGH** - Can't link tokens to Beads issues |
| **Real-time metrics** | ⚠️ Statusline only | **MEDIUM** - Need in-flight tracking |
| **Agent attribution** | ❌ None | **HIGH** - Which agent consumed tokens? |
| **Stage timing** | ❌ None | **MEDIUM** - Duration vs token consumption |
| **Workflow path tracking** | ❌ None | **MEDIUM** - Fast-track vs full workflow costs |

---

## 2. Current State: Token Tracking Architecture

### Data Sources

**stats-cache.json** (Daily aggregates):
```json
{
  "2026-01-31": {
    "messages": 3319,
    "claude-opus-4-5-20251101": {
      "inputTokens": 194,
      "outputTokens": 0,
      "cacheReadInputTokens": 189063195,
      "cacheCreationInputTokens": 0
    },
    "claude-sonnet-4-5-20250929": {
      "inputTokens": 8673622,
      "outputTokens": 1234039
    }
  }
}
```
- ✅ Model breakdown (Opus/Sonnet)
- ✅ Cache metrics
- ❌ No task/workflow correlation
- ❌ No stage attribution

**history.jsonl** (16,454 messages, 116 sessions):
```json
{
  "display": "user message text",
  "timestamp": "2026-01-31T...",
  "sessionId": "abc123",
  "project": "/Users/tomas/.claude"
}
```
- ✅ Session IDs
- ✅ Timestamps
- ❌ No token counts
- ❌ No agent/stage tags

### Workflow Structure (Beads)

Current task hierarchy:
```
.claude-4nq (Epic)
├── .claude-4nq.1-analyze   (Analyst + Opus)
├── .claude-4nq.2-plan      (Planner + Sonnet)
├── .claude-4nq.3-implement (Implementer + Sonnet)
└── .claude-4nq.4-review    (Reviewer + Opus)
```

**Key Insight**: Task IDs already encode stage structure - perfect for token attribution!

---

## 3. Integration Architecture

### Option A: Custom Instrumentation + ccusage Reporting (RECOMMENDED)

**Approach**: Extend workflow system to write structured token metrics, use ccusage for analysis.

#### Phase 1: Data Collection Layer

**1.1 Create Workflow Metrics JSONL**

New file: `.claude/workflow-metrics.jsonl`

```json
{
  "timestamp": "2026-01-31T14:23:45Z",
  "workflow_id": ".claude-4nq",
  "task_id": ".claude-4nq.1-analyze",
  "stage": "analyze",
  "agent": "analyst",
  "model": "claude-opus-4-5-20251101",
  "session_id": "abc123",
  "tokens": {
    "input": 12450,
    "output": 3201,
    "cache_read": 45600,
    "cache_creation": 0
  },
  "cost_usd": 0.245,
  "duration_seconds": 127,
  "status": "completed"
}
```

**1.2 Instrument Agent Lifecycle**

Hook points in workflow execution:

```bash
# Pseudo-code for master agent workflow invocation

START_TRACKING() {
  WORKFLOW_ID=$(bd show $TASK_ID | grep "^ID:")
  STAGE_TASK_ID="${WORKFLOW_ID}.1-analyze"
  START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Write start marker
  echo "{\"event\":\"stage_start\",\"task_id\":\"$STAGE_TASK_ID\",\"started_at\":\"$START_TIME\"}" \
    >> .claude/workflow-metrics.jsonl
}

END_TRACKING() {
  # Capture from Claude Code API response (requires hook into Claude infrastructure)
  # OR parse from session logs if accessible

  echo "{\"event\":\"stage_end\",\"task_id\":\"$STAGE_TASK_ID\",\"tokens\":{...}}" \
    >> .claude/workflow-metrics.jsonl
}
```

**1.3 Beads Integration**

Store per-stage metrics as bd comments:

```bash
# After each stage completes
bd comment .claude-4nq.1-analyze << EOF
## Token Usage Metrics

- **Input tokens**: 12,450
- **Output tokens**: 3,201
- **Cache read**: 45,600
- **Cost**: \$0.245
- **Duration**: 2m 07s
- **Model**: Opus 4.5

Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
EOF
```

Benefits:
- ✅ Queryable via `bd comments .claude-4nq.1-analyze`
- ✅ Persists in git with task history
- ✅ Human-readable in `bd show` output
- ✅ Structured enough for parsing

#### Phase 2: Analysis Layer

**2.1 Custom Analytics Script**

Create: `scripts/workflow-analytics.sh`

```bash
#!/bin/bash
# Analyze workflow token consumption

WORKFLOW_ID="$1"

# Extract all stage metrics for workflow
jq -r --arg wf "$WORKFLOW_ID" '
  select(.workflow_id == $wf) |
  [.stage, .tokens.input, .tokens.output, .cost_usd, .duration_seconds] |
  @tsv
' .claude/workflow-metrics.jsonl | \
  awk 'BEGIN {
    printf "%-12s %10s %10s %8s %10s\n", "Stage", "Input", "Output", "Cost", "Duration"
  } {
    printf "%-12s %10d %10d $%7.3f %8ds\n", $1, $2, $3, $4, $5
  }'
```

**2.2 ccusage Integration**

Use ccusage for complementary analytics:

```bash
# Daily cost overview (native ccusage)
npx ccusage@latest --breakdown

# Per-workflow deep dive (custom script)
./scripts/workflow-analytics.sh .claude-4nq

# Session correlation
npx ccusage@latest --instances | grep "session-abc123"
```

**2.3 Reporting Dashboards**

Combine both sources:

```bash
# High-level: Monthly spending (ccusage)
npx ccusage@latest --monthly

# Mid-level: Daily breakdown by model (ccusage)
npx ccusage@latest --breakdown --since 2026-01-01

# Low-level: Workflow-specific costs (custom)
./scripts/workflow-cost-report.sh --workflow .claude-4nq --compare .claude-4nx
```

---

### Option B: ccusage MCP Server Extension (ADVANCED)

**Approach**: Extend ccusage's MCP (Model Context Protocol) server to expose workflow-aware APIs.

#### Architecture

```
Claude Code
    ↓ (API calls with metadata)
ccusage MCP Server (custom extension)
    ↓ (writes to)
workflow-metrics.db (SQLite)
    ↓ (queried by)
ccusage CLI + Custom Dashboard
```

#### Pros:
- ✅ Centralized metrics storage
- ✅ Real-time queryable via MCP
- ✅ Could integrate with ccusage's existing reporting
- ✅ Structured schema with relationships

#### Cons:
- ❌ Requires deep ccusage codebase modification
- ❌ Maintenance burden on upstream updates
- ❌ May not be feasible if Claude Code API doesn't expose token counts in real-time
- ❌ Higher complexity vs. Option A

---

### Option C: Passive Log Parsing (LIGHTWEIGHT)

**Approach**: Parse existing logs post-execution without instrumentation.

#### Implementation

```bash
# Extract token counts from session logs (if available)
grep -E "token|usage" ~/.claude/sessions/*/log.txt | \
  jq -R 'fromjson?' | \
  jq -s 'group_by(.session_id) | map({session: .[0].session_id, total_tokens: map(.tokens) | add})'
```

#### Pros:
- ✅ No code changes required
- ✅ Works with existing data
- ✅ Lowest implementation effort

#### Cons:
- ❌ Dependent on log format (undocumented, may change)
- ❌ No real-time tracking
- ❌ Requires reverse-engineering token data location
- ❌ May not have stage/task correlation

---

## 4. Recommended Implementation Plan

### Phase 1: Foundation (Week 1-2)

**Goal**: Prove concept with minimal instrumentation

1. **Investigate Claude Code token exposure**
   - Determine if token counts are accessible via:
     - Environment variables during agent execution
     - Response headers/metadata
     - Session log files
   - If not exposed: Request feature from Anthropic

2. **Prototype JSONL metrics collection**
   - Create `.claude/workflow-metrics.jsonl`
   - Manually instrument one workflow invocation
   - Validate data structure

3. **Beads comment integration**
   - Add token metrics to one stage's completion
   - Test `bd comments` retrieval
   - Validate human readability

### Phase 2: Automation (Week 3-4)

**Goal**: Automatic tracking for all workflows

1. **Hook development workflow**
   - Modify `commands/develop.md` to start tracking on invocation
   - Inject tracking context into master agent prompt
   - Capture tokens at each stage boundary

2. **Master agent updates**
   - Add tracking wrapper around `Task` tool calls
   - Store workflow_id → task_id mapping
   - Write start/end events to metrics JSONL

3. **Analytics scripts**
   - `workflow-analytics.sh`: Per-workflow breakdown
   - `stage-comparison.sh`: Compare stages across workflows
   - `cost-attribution.sh`: Which workflows cost most?

### Phase 3: Integration (Week 5-6)

**Goal**: Unified reporting with ccusage

1. **ccusage configuration**
   - Install: `npm install -g ccusage@latest`
   - Configure timezone and locale
   - Set up scheduled reports (daily email/Slack)

2. **Dual-mode reporting**
   - High-level dashboard: ccusage native reports
   - Detailed drilldown: Custom workflow scripts
   - Document usage patterns for team

3. **Optimization insights**
   - Identify high-cost stages
   - Analyze fast-track vs. full-workflow ROI
   - Cache optimization opportunities

---

## 5. Cost-Benefit Analysis

### Implementation Costs

| Phase | Effort (hours) | Complexity | Risk |
|-------|----------------|------------|------|
| Phase 1 (Prototype) | 8-16 | Low | Low - isolated experiment |
| Phase 2 (Automation) | 20-30 | Medium | Medium - requires workflow changes |
| Phase 3 (Integration) | 10-15 | Low | Low - mostly configuration |
| **Total** | **38-61** | **Medium** | **Medium** |

### Benefits

**Quantifiable**:
- **Cost attribution**: Identify which workflows consume most tokens → prioritize optimization
- **Stage efficiency**: Measure analyst vs. implementer costs → optimize agent selection
- **Cache ROI**: Track cache hit rates per workflow → validate caching strategy
- **Model selection**: Opus vs. Sonnet cost comparison → data-driven model choices

**Expected Savings** (assuming 10% optimization):
- Current daily usage: ~9M tokens/day (from stats-cache.json)
- At ~$0.015/1K tokens (blended rate): ~$135/day = $4,050/month
- 10% reduction: **$405/month saved** = **$4,860/year**
- Pays for implementation in ~1.5 months

**Qualitative**:
- ✅ Transparency into workflow costs
- ✅ Data-driven optimization decisions
- ✅ Identify underperforming stages
- ✅ Justify workflow design choices
- ✅ Enable per-client/per-project billing (if applicable)

---

## 6. Technical Feasibility Assessment

### Blockers

| Blocker | Severity | Mitigation |
|---------|----------|------------|
| **Token counts not exposed by Claude Code** | 🔴 CRITICAL | Contact Anthropic support; fallback to log parsing |
| **Agent invocation hooks unavailable** | 🟡 MEDIUM | Instrument at master level; accept coarser granularity |
| **JSONL write performance** | 🟢 LOW | Append-only writes are fast; rotate files monthly |
| **ccusage schema incompatibility** | 🟢 LOW | Use separate metrics file; ccusage for aggregates only |

### Unknowns Requiring Investigation

1. **How does Claude Code expose token counts?**
   - Check: Environment variables during agent execution
   - Check: Session metadata files
   - Check: API response headers (if accessible)

2. **Can we inject metadata into agent context?**
   - Test: Add custom YAML frontmatter to agent prompts
   - Test: Environment variable propagation to subagents

3. **Does ccusage support custom data sources?**
   - Review: ccusage source code for plugin architecture
   - Test: MCP server extension points

---

## 7. Alternative Approaches

### If Token Counts Are Not Accessible

**Fallback Strategy: Estimator Model**

1. **Collect training data**
   - Manually record token counts for 50-100 workflows
   - Features: file changes, code lines, comment length, agent turns

2. **Build regression model**
   ```python
   tokens_estimated = β0 + β1(files_changed) + β2(lines_of_code) + β3(agent_turns)
   ```

3. **Validate accuracy**
   - Test on held-out workflows
   - Accept ±20% error margin for planning purposes

**Pros**: Better than no tracking
**Cons**: Inaccurate, requires maintenance, doesn't capture model differences

---

## 8. Recommendations

### Immediate Actions (This Week)

1. ✅ **Install ccusage**: `npm install -g ccusage@latest`
2. 🔍 **Investigate token exposure**: Check Claude Code docs/source for API access
3. 📊 **Run ccusage baseline**: `npx ccusage@latest --breakdown --since 2026-01-01`
4. 📝 **Document current costs**: Establish baseline for optimization tracking

### Short-term (Next 2 Weeks)

1. **Prototype instrumentation**: Manually track one workflow end-to-end
2. **Validate Beads integration**: Test token metrics in `bd comments`
3. **Create analytics script**: Simple workflow cost breakdown
4. **Decision point**: Proceed with Option A (custom) or Option B (MCP extension) based on findings

### Long-term (Next 2 Months)

1. **Full automation**: All workflows automatically tracked
2. **Reporting dashboards**: Combine ccusage + custom scripts
3. **Optimization cycle**: Identify → measure → optimize → validate
4. **Team training**: Document usage patterns and cost optimization best practices

---

## 9. Conclusion

**ccusage is a valuable tool for aggregate analytics**, but your workflow system requires **custom instrumentation for per-workflow and per-stage granularity**. The recommended hybrid approach:

1. **Extend your workflow system** with JSONL-based metrics collection
2. **Integrate with Beads** for persistent, queryable token data
3. **Leverage ccusage** for high-level reporting and cost tracking
4. **Build custom scripts** for workflow-specific analysis

**Success Metrics**:
- ✅ Track 100% of workflow invocations with per-stage breakdown
- ✅ Correlate token costs with Beads task IDs
- ✅ Identify top 3 cost drivers within 1 month
- ✅ Achieve 10%+ cost reduction through optimization within 3 months

**Next Step**: Investigate token count exposure in Claude Code API (blocker for all options).

---

**References**:
- ccusage: https://github.com/ryoppippi/ccusage
- Project workflows: `/Users/tomas/.claude/agents/`
- Beads documentation: `/Users/tomas/.claude/.beads/`
- Current metrics: `/Users/tomas/.claude/stats-cache.json`
