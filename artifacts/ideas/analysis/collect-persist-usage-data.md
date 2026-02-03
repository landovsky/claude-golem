# Collect and persist usage data (per task, per workflow stage)

**Created**: 2026-02-03

## What
Track usage metrics (tokens, costs, time, API calls) per beads task and per workflow stage (analyst, planner, implementer, reviewer).

## Why Now
Need visibility into costs, performance, and bottlenecks in the workflow system.

**Specific triggers**:
1. Get questions about workflow efficiency → need A/B testing (same task with/without workflow)
2. Token leaks → need anomaly detection for unexpectedly high usage
3. General understanding → need visibility into token distribution across stages

**Constraint**: Must work in remote execution environment (git-based persistence OK for now)

## Initial Thoughts
- Aggregate ccusage data by task ID and workflow stage
- Store in database or structured files
- Enable queries like "What did task X cost?" or "Which stage uses most tokens?"
- Could inform workflow optimization

## Questions
- Where to store (SQLite, PostgreSQL, JSONL)?
- How to associate usage with task/stage (context tracking)?
- Real-time or post-hoc analysis?
- What metrics matter most (cost, tokens, time, success rate)?
- Privacy/security considerations for API usage data?

---

---

## Challenge Q&A

### Problem Definition

**Q: Are these problems you're experiencing NOW?**
A: YES. Completely blind to workflow costs - only see aggregate usage in Claude app UI. This should exist even in lightweight form.

**Q: Who has this problem?**
A: Me (maintainer). Need to understand and explain workflow efficiency.

**Q: How painful? (1-10)**
- Benchmarking: 7/10 - Need to understand workflow overhead
- Leak detection: 0/10 (don't need automatic detection)
- **Data collection: 10/10** - Critical need for raw data to view/interpret
- Understanding token distribution: 9/10 - Highly needed, not breaking but essential

**Q: What if we do nothing?**
A: Could theoretically inspect ccusage manually, but unclear how that works in remote execution. Currently completely blind.

### Alternatives

**Q: What's the simplest way to solve this?**
A: Happy with **integrating existing components** (ccusage + beads) as long as data persists in remote execution. Lightweight approach preferred.

**Q: What are we NOT doing if we spend time on this?**
A: "Instead of working on this, I could be using the time building something using the Golem workflow." Opportunity cost = not using the workflow productively.

**BUT**: "This feels important" - visibility is high priority even if not a hard blocker.

**Q: Can we buy/reuse/configure instead of build?**
A: **Investigated ccusage** (see `artifacts/workflow-design/docs/ccusage-integration-evaluation.md` from 2026-02-01):

- ✅ ccusage provides daily/monthly aggregates, model breakdowns, cache metrics
- ❌ ccusage lacks per-workflow tracking, per-stage granularity, task ID correlation
- ✅ **Recommended solution**: Custom instrumentation (JSONL) + Beads integration + ccusage for reporting
- ⏱️ **Estimated effort**: 38-61 hours (3 phases)
- 💰 **ROI**: $405/month savings, pays for itself in 1.5 months
- 🔴 **Critical blocker**: Token counts may not be exposed by Claude Code API

**Why not implemented yet**: Proper validation process wasn't in place - doing that now.

### Assumptions & Risks

**Q: What are we assuming is true?**
1. **Token count accessibility**: ✅ SOLVED - https://code.claude.com/docs/en/monitoring-usage provides API access
2. **Git-based persistence**: ✅ Non-issue, should be fine for remote execution
3. **Effort estimate (38-61 hours)**: Not relevant - AI development time doesn't count
4. **ROI calculation**: Not relevant - **this is a hobby project**, value is intrinsic (understanding, transparency)

**Q: What could make this idea worthless?**
🔴 **PRIMARY RISK**: "Collected data are not inspected/interpreted or not actionable"
- Risk of building metrics shelfware that never gets used
- Need to ensure data is actually consumed and leads to insights

**Q: What could go wrong?**
Covered above - main risk is building unused infrastructure.

### Scope

**Q: Can this be smaller?**
A: **YES - Phase 1 only**. Scope = collect metrics as JSONL entries. Data evaluation/automation out of scope.

**Q: What's the MVP?**
A: Phase 1 from evaluation doc:
- JSONL metrics collection (`.claude/workflow-metrics.jsonl`)
- Store per-stage metrics in beads comments
- Basic queryability via `jq` or `bd comments`
- Estimated effort: 8-16 hours (AI-assisted)

**Actionability clarification**: Not worried about forgetting to inspect data (will set calendar reminders). Concerned that data might not reveal actionable insights.

**Mitigation**: Use cases (benchmarking, leak detection, understanding distribution) should provide actionable insights:
- "Workflow adds X% overhead" → decide if worth it
- "Stage Y had 5x normal tokens" → investigate bug/leak
- "Analyst stage dominates cost" → consider model optimization

---

## Validation Decision

✅ **VALIDATED - Created in beads**

**Beads ID**: `.claude-l0a`
**Type**: feature
**Priority**: P1 (Quick Win: high value, small effort)
**Status**: open (ready to implement)

**Why validated**:
- Real high-pain problem (9-10/10 pain)
- Concrete actionable use cases (benchmarking, leak detection, understanding)
- Right-sized scope (Phase 1 only - JSONL + beads comments)
- Technical feasibility confirmed (token API exists, git persistence works)
- Foundation exists (evaluation doc provides architecture)

**Next steps**:
```bash
bd show .claude-l0a          # Review full context
/develop .claude-l0a         # Start implementation when ready
```

## Status
- [x] Not yet challenged
- [x] Challenged - awaiting decision
- [x] Validated - ready for beads
- [ ] Discarded

---

**Next**: Run `/validate collect-persist-usage-data` to challenge and validate this idea.
