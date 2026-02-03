# Discovery Workflow

**Purpose**: Validate ideas before they become work.

**Principle**: Not every idea deserves implementation. Challenge assumptions, prioritize ruthlessly, focus on impact.

---

## The Funnel

```
Raw Idea → Challenge → Validate → Prioritize → Graduate (or Archive)
   ↓          ↓          ↓           ↓             ↓
 Capture   Critical   Reality    Stack Rank    /develop
           Thinking    Check                   (beads task)
```

---

## Stage 1: Capture (Raw Ideas)

**Goal**: Brain dump without judgment or commitment.

**Method**: Ephemeral notes, scratch file, or just your head.

**Don't persist yet** - 90% of raw ideas will be filtered out.

**Template** (if you want to write it down): `artifacts/ideas/scratch/<slug>.md`

```markdown
# [Idea Title]

## What
[1-2 sentences describing the idea]

## Why Now
[What triggered this? What problem does it solve?]

## Initial Thoughts
- [Bullet points, stream of consciousness]
- [No filtering yet]

## Questions
- [Unknowns, assumptions to test]
```

**No judgment yet** - just capture the spark.

**Note**: The `scratch/` directory is git-ignored. Don't commit raw, unvalidated ideas.

---

## Stage 2: Challenge (Critical Analysis)

**Goal**: Stress-test the idea. Find flaws early.

**Method**: Run through challenge questions, update idea file.

### Challenge Framework

```markdown
## Challenge Questions

### Problem Definition
- **What problem does this solve?**
  - [Be specific. "It would be cool" is not a problem.]

- **Who has this problem?**
  - [You? Team? Users? External stakeholders?]

- **How painful is the problem?** (1-10)
  - [1 = minor annoyance, 10 = critical blocker]

- **What's the cost of NOT solving it?**
  - [What happens if we do nothing?]

### Alternatives
- **What's the simplest solution?**
  - [Often it's not building something new]

- **What are we NOT doing if we do this?**
  - [Opportunity cost - what gets delayed?]

- **Could we buy/reuse instead of build?**
  - [Existing tools, libraries, patterns?]

### Assumptions
- **What are we assuming is true?**
  - [List all assumptions]

- **What could invalidate this idea?**
  - [What would make this worthless?]

- **What could go wrong?**
  - [Risks, dependencies, unknowns]

### Scope Reality Check
- **Can this be smaller?**
  - [What's the 20% that delivers 80% value?]

- **What's the MVP?**
  - [Absolute minimum to test the hypothesis]
```

**Action**: If the analysis reveals valuable insights, save to `artifacts/ideas/analysis/<slug>.md` for reference. Otherwise, just discard.

**Decision Point**: If challenges reveal the idea is weak, kill it. No shame in discarding bad ideas early. Don't persist weak ideas.

---

## Stage 3: Validate (Reality Check)

**Goal**: Ensure alignment with goals and timing.

**Method**: Score the idea on key dimensions.

```markdown
## Validation Scorecard

### Strategic Fit
- **Aligns with project goals?** [yes/no/partially]
  - [Which goals? How?]

- **Right time to do this?** [yes/no/later]
  - [Dependencies, prerequisites, context]

- **Who benefits and how much?** [high/medium/low value]
  - [Quantify if possible]

### Feasibility
- **Do we have the skills/tools?** [yes/no/learn-required]

- **What's unknown?** [list unknowns]

- **Can we prototype first?** [yes/no]
  - [Spike to reduce risk?]

### ROI (Value vs Cost)
- **Expected value**: [high/medium/low]
  - [Cost savings, revenue, productivity, quality, learning]

- **Expected effort**: [small/medium/large/xl]
  - [Small=hours, Medium=days, Large=weeks, XL=months]

- **ROI calculation**: [value/effort]
  - High value + small effort = DO THIS
  - High value + large effort = CONSIDER
  - Low value + any effort = SKIP

### Risk Assessment
- **Technical risk**: [low/medium/high]
  - [Can it be built reliably?]

- **Execution risk**: [low/medium/high]
  - [Can we deliver on time/budget?]

- **Impact risk**: [low/medium/high]
  - [What breaks if this fails?]
```

**Action**: Create in beads as `type=idea` and mark as blocked:

```bash
bd create "Idea title" \
  --type=idea \
  --priority=2 \
  --description="Problem: [what]

Value: [high/medium/low] - [why]
Effort: [small/medium/large] - [estimate]
ROI: [value/effort]

Alternatives considered:
- [alternative 1]
- [alternative 2]

Assumptions:
- [assumption 1]
- [assumption 2]

Risks: [technical/execution/impact]

Next steps: [what needs to happen to be ready]"

# IMPORTANT: Mark as blocked to prevent accidental implementation
bd update <idea-id> --status=blocked
bd comments add <idea-id> "Blocked: Validated idea, not yet graduated. Unblock when ready to implement."
```

**Why blocked?** Prevents accidentally passing `type=idea` to `/develop`. Ideas must be explicitly graduated to tasks.

**Decision Point**: If validation fails (low ROI, wrong time, high risk), don't create in beads. Just discard or defer.

---

## Stage 4: Prioritize (Stack Rank)

**Goal**: Order validated ideas by impact and urgency.

**Method**: Use beads priorities and status.

```bash
# Update priority as understanding evolves
bd update <idea-id> --priority=1  # P1: High priority

# List all ideas by priority
bd list --type=idea --status=open

# Mark as deferred (not closed, just not now)
bd update <idea-id> --status=blocked
bd comments add <idea-id> "Deferring: dependencies not ready"

# Kill bad ideas (close them)
bd close <idea-id> --reason="ROI too low after analysis"
```

**Prioritization Matrix**:

```
Impact ↑
   │
 H │  P1 (Quick Wins!)     P0 (Big Bets)
   │
 M │  P2 (Fill-ins)        P1 (Careful Planning)
   │
 L │  P3 (Backlog)         P3 (Avoid)
   │
   └────────────────────────────────────> Effort
        S         M         L        XL
```

**View priorities**:
```bash
# High priority ideas ready to work on
bd list --type=idea --priority=0,1 --status=open

# All open ideas sorted by priority
bd list --type=idea --status=open
```

**Re-prioritize regularly** (weekly or when new ideas enter):
- Review `bd list --type=idea`
- Update priorities based on current context
- Close ideas that are no longer relevant

---

## Stage 5: Graduate (Ready for Develop)

**Goal**: Hand off validated, prioritized idea to `/develop` workflow.

**Method**: When ready to work on an idea, convert it to a task.

### Graduation Checklist

- [ ] Problem is clearly defined
- [ ] Alternatives considered
- [ ] Assumptions documented
- [ ] Validated for ROI and fit
- [ ] Prioritized appropriately
- [ ] Has clear acceptance criteria
- [ ] Unknowns are acceptable (or spiked)

### Graduate to Task

```bash
# Unblock and convert idea to task
bd update <idea-id> --status=open --type=task

# Verify graduation
bd show <idea-id>  # Now shows type=task, status=open

# Hand to /develop workflow
/develop <idea-id>
```

**Why unblock?** Ideas are created as `status=blocked` to prevent accidental implementation. Graduation unblocks and converts to task.

**What happens next**:
1. Master reads the beads task (which has all your validation context)
2. Master assesses complexity and specification completeness
3. Master routes to fast-track or full workflow
4. Work begins!

**After completion**:
- Master closes the beads task
- Idea has graduated from concept → shipped feature

---

## Storage Strategy (Hybrid)

**Early stages** (Raw, Challenged): Lightweight markdown files - not persisted unless valuable

**Validated stage**: Create in beads as `type=idea`
- `bd create "Title" --type=idea --priority=2 --description="..."`
- Tracked, prioritized, git-backed
- Filtered from task lists: `bd list --type=task` (no ideas shown)

**Ready stage**: Convert to task and hand to `/develop`
- `bd update <id> --type=task`
- Now it's work, not just an idea
- Master's `/develop` workflow takes over

### Directory Structure

```
artifacts/
└── ideas/
    ├── scratch/          # Raw thinking, ephemeral notes (git-ignored)
    ├── analysis/         # Challenged ideas worth documenting
    └── PRIORITIES.md     # View of validated ideas from beads
```

**Why this works**:
- 90% of raw ideas die quickly (don't persist them)
- Challenged ideas with valuable analysis get documented
- Validated ideas live in beads (`type=idea`)
- Ready ideas become tasks in beads (`type=task`)
- Single source of truth (beads), no dual systems

---

## Command: `/validate`

Facilitate the validation workflow with an interactive command:

```bash
/validate [idea-title]
```

**What it does**:
1. Captures raw idea (title + initial description)
2. Asks challenge questions interactively
3. Guides through validation scorecard
4. Calculates ROI score
5. If validated: creates `bd` issue with `--type=idea`
6. If not validated: explains why and discards
7. Suggests next steps (prioritize, defer, or kill)

---

## Integration with `/develop`

### Before `/develop`:
1. Idea validated via `/validate` workflow
2. Problem clearly defined
3. Alternatives considered
4. ROI established

### Invoking `/develop`:
```bash
# Graduate idea to task
bd update .claude-xyz --type=task

# Start development workflow
/develop .claude-xyz
```

Master reads the beads task, sees all the validation context from discovery, and assesses complexity with full background.

### After completion:
- Master closes beads task (now type=task)
- Idea has successfully graduated from concept → working code

---

## Rules

1. **No beads until validated** - Raw/challenged ideas stay ephemeral
2. **type=idea until ready** - Use `bd create --type=idea` only after validation
3. **Challenge everything** - If you can't articulate the problem, don't persist it
4. **Kill bad ideas early** - Discarding is success, not failure
5. **Re-prioritize often** - P0 yesterday might be P3 today
6. **Graduate consensually** - Convert `type=idea` → `type=task` when truly ready
7. **Keep it lightweight** - Most thinking happens in your head, not in files

---

## Success Metrics

You're doing this right if:
- ✅ Most ideas get challenged and archived (filtering works!)
- ✅ Only high-ROI ideas graduate to `/develop`
- ✅ You spend more time thinking, less time reworking
- ✅ Beads stays clean (work only, not ideas)
- ✅ You feel confident about what you're building

---

## Example Flow

### Week 1: Raw Idea
- You think: "Sync beads to GitHub"
- Don't persist yet - just a spark

### Week 1: Challenge (In Your Head)
- Why? → Team visibility? Triggering? Backup?
- Alternative? → Web UI? API? Keep beads-only?
- Realizes: Problem unclear, need to clarify first

### Week 2: Clarify & Validate
- After discussion, clearer problem: "Non-CLI users need visibility"
- Alternative: Simple web viewer (simpler than GitHub sync)
- Value: Medium (helps team), Effort: Small (read-only display)
- ROI: High (medium value / small effort)
- Decision: **Validated**

### Week 2: Create in Beads (Blocked)
```bash
bd create "Build read-only web viewer for beads" \
  --type=idea \
  --priority=1 \
  --description="Problem: Team members without CLI access can't see task status

Value: Medium - Improves team visibility
Effort: Small - Read-only web app (no sync complexity)
ROI: High (medium/small)

Alternatives:
- GitHub sync (rejected - too complex)
- Slack notifications (doesn't solve visibility)
- Email reports (not real-time)

Assumptions:
- Team wants web access
- Read-only is sufficient

Next: Design simple web UI, plan tech stack"

# Returns: .claude-abc

# Mark as blocked until graduated
bd update .claude-abc --status=blocked
bd comments add .claude-abc "Blocked: Validated idea, not yet ready to implement"
```

### Week 3: Prioritize
```bash
# List ideas (including blocked ones)
bd list --type=idea
# Shows: .claude-abc (P1, blocked), .claude-xyz (P2, blocked), .claude-def (P2, blocked)
# Decide to work on .claude-abc first
```

### Week 4: Graduate & Develop
```bash
# Ready to work on it - unblock and convert to task
bd update .claude-abc --status=open --type=task

# Verify graduation
bd show .claude-abc  # type=task, status=open

# Start development workflow
/develop .claude-abc

# Master assesses: "Simple task, specs complete"
# Master fast-tracks implementation
```

### Week 5: Complete
- Work is done, tested, merged
- Master closes `.claude-abc`
- Idea successfully graduated from concept → shipped feature

---

## Anti-Patterns to Avoid

❌ **Idea hoarding**: Keeping 100 ideas in beads as `type=idea`
  → Close ruthlessly, keep open ideas under 20

❌ **Analysis paralysis**: Spending weeks validating
  → Time-box validation (1-2 hours max per idea)

❌ **Priority inflation**: Everything is P0
  → Only 1-3 items can be P0 at a time

❌ **Skipping validation**: Creating `type=task` directly
  → Start as `type=idea`, validate, then convert to `type=task`

❌ **No re-prioritization**: Set-and-forget idea priorities
  → Review `bd list --type=idea` weekly

❌ **Persisting too early**: Creating beads for raw ideas
  → Only create `type=idea` after validation passes

---

## Next Steps

1. Create directory structure (`artifacts/ideas/scratch/`, `artifacts/ideas/analysis/`)
2. Add `scratch/` to `.gitignore` (don't commit raw ideas)
3. Build `/discover` skill command
4. Test with 1-2 ideas:
   - Challenge them
   - Validate ROI
   - Create as `type=idea` if worthy
5. Prioritize validated ideas
6. Graduate 1 idea to `type=task` and run `/develop`
7. Iterate on the process

**Remember**: This is about FOCUS. Say no to 90% of ideas so you can say yes to the 10% that matter.
