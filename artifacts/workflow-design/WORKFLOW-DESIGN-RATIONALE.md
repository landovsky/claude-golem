# Design Rationale: AI Development Workflow

This document captures the reasoning process behind the workflow design. It helps future maintainers understand not just *what* the workflow does, but *why* it's structured this way.

---

## The Problem We Were Solving

**Core need:** A workflow for AI-assisted development that ensures due process (specify → plan → implement → review) while not over-processing simple tasks.

**Constraints:**
- Must work across any tech stack (Ruby, Python, Node, etc.)
- Must integrate with `bd` for task tracking
- Must support project-specific artifacts (style guides, conventions) without hardcoding them
- Must give each agent just enough context to do their job well

**Anti-goals:**
- Not a rigid state machine - agents have judgment
- Not a replacement for what Claude already does well (planning, coding)
- Not trying to eliminate all error - room for invention includes room for mistakes

---

## Design Process

We went through three rounds of critique before implementation, then a review round after.

### Round 1: "What's Missing?"

Initial requirements were too vague. Critique surfaced:

| Gap | Question |
|-----|----------|
| Entry/exit | When does workflow start? When is "done"? |
| Complexity | Who judges "simple" vs "complex"? What criteria? |
| Human role | When exactly does the human intervene? |
| Context flow | What's the format? Who curates? How much? |
| Planner scope | What does Claude already do vs. what we add? |
| Reviewer loop | Issues found, then what? |
| Artifact discovery | Convention or configuration? |

**Key insight:** The initial spec was trying to build a state machine. That's wrong for AI workflows where agents already have judgment.

### Round 2: "What Are We Actually Building?"

Requester clarified intent:

> "I don't want to reinvent what these tools are already doing... I want to leave room for invention (and inherently error)."

This reframed the problem from "control everything" to "guardrails and conventions":

**Decided:**
- Sequential process (no parallelism complexity)
- Merge explorer + specifier (too much overlap)
- Agents self-determine completion (don't over-specify)
- Loose on behavior, tight on bd tracking

### Round 3: "Make It Concrete"

Final pressure-testing resolved implementation details:

| Question | Resolution |
|----------|------------|
| Who creates subtasks? | Master, upfront based on path |
| Merged agent naming? | "Analyst" (implies both analysis and specification) |
| Blocked handling? | Agent blocks → master proposes solution → human decides |
| Reviewer rejection? | Triage, fix critical/major directly |
| Artifact format? | `registry.json` with usage: `always` or `decide` |

### Review Round: "Calibrate the Agents"

After implementation, review feedback led to significant refinements:

**Analyst feedback:**
> "Way too technical - needs 40/60 business/technical"

Changed to lead with understanding the request, then deep codebase exploration, validate against existing patterns, cover edge cases existing code handles. Removed "Technical approach" (that's planner's job).

**Planner feedback:**
> "Think about planner as helping a medior developer see around corners"

Reframed from "task list" to "enabler" - provide context, warnings, dependencies, not prescriptive instructions.

**Implementer feedback:**
> "Guidelines are strict as if he were a junior... let's give him room to remedy upstream mistakes"

Gave autonomy to use judgment, remedy analyst/planner gaps, with safety valve: consult master if going off-course.

**Terminology feedback:**
> "Let's remove ambiguity - bd items are issues of kind task or epic"

Standardized: issue (any bd item), task (work unit with sub-tasks), epic (depends on tasks), sub-task (workflow stage).

**Splitting feedback:**
> "If splitting, task should be updated to epic to prevent duplicates"

Convert original task to epic rather than creating shadow entity alongside.

**Lessons-learned feedback:**
> "Points to a file that no-one reads"

Clarified: lives at `.claude/lessons-learned.md`, planner explicitly reads it. Closed loop.

**Documenter question:**
> "Do we need this role?"

No - distributed responsibility: analyst flags, planner assigns, implementer does, reviewer verifies.

---

## Decisions Log

### Decision 1: Fast-Track vs Full Workflow

**Options considered:**
- A) Always full workflow
- B) Human decides which path
- C) Master decides, human can override

**Chose C.** Full workflow for typo fixes is wasteful. Human deciding adds friction. Master can assess with examples, expose reasoning, human intervenes only if they disagree.

### Decision 2: Task Hierarchy

**Options considered:**
- A) Flat tasks only
- B) Three levels: epic → task → subtask
- C) Two levels: task with sub-tasks, epics separate

**Chose C.** Deep nesting adds coordination overhead. Two levels (parent + workflow stages) is enough. Epics are separate entities with dependencies, not containers.

### Decision 3: Analyst Scope

**Options considered:**
- A) Separate explorer and specifier agents
- B) Merged "analyst" agent
- C) Skip analysis, just plan

**Chose B.** You can't specify without exploring. Exploration informs what questions to ask. Separation creates artificial handoff. Merged is heavier but simpler flow.

**Calibration:** Initial version was overly technical. Recalibrated to 40/60 business/technical after review - enough business context to validate requirements, but primarily focused on codebase exploration.

### Decision 4: Planner Purpose

**Options considered:**
- A) Detailed implementation instructions
- B) Thin addendum to spec
- C) Context and warnings for capable implementer

**Chose C.** Claude already plans well. Detailed instructions duplicate that. Thin addendum doesn't add value. Senior-helping-medior framing gives purpose: surface what's non-obvious, enable good decisions.

### Decision 5: Implementer Autonomy

**Options considered:**
- A) Strict plan follower (junior model)
- B) Full autonomy (senior model)
- C) Autonomy with safety valve (medior model)

**Chose C.** Strict following propagates upstream mistakes. Full autonomy might deviate unnecessarily. Safety valve (consult master if off-course) balances capability with alignment.

### Decision 6: Reviewer Feedback Loop

**Options considered:**
- A) Route all issues back to implementer
- B) Reviewer fixes everything
- C) Triage: fix critical/major, document minor

**Chose C.** Routing back creates ping-pong delays. Fixing everything is overkill. Triage focuses effort: critical/major get fixed (they matter), minor get documented (they don't block).

### Decision 7: Lessons-Learned Location

**Options considered:**
- A) In artifacts/ (project knowledge)
- B) In .claude/ (workflow knowledge)
- C) External system

**Chose B.** It's process memory, not domain knowledge. Lives alongside specs and plans. Planner reads it - the loop is closed within the workflow.

### Decision 8: Documentation Responsibility

**Options considered:**
- A) Separate documenter agent
- B) Master handles at end
- C) Distributed across existing agents

**Chose C.** Separate agent adds handoff. Master at end is too late. Distributed: analyst flags what needs updating, planner assigns it, implementer does it, reviewer verifies. Documentation is part of the work.

---

## What We Rejected

| Idea | Why Rejected |
|------|--------------|
| Parallel agent execution | Coordination complexity not worth it for most tasks |
| Approval gates at each step | Adds friction, human can interrupt anyway |
| Automatic rollback on failure | Blocked = human judgment needed, not retry |
| Task templates | Don't fit, create false confidence |
| Metrics/velocity tracking | Separate concern, not part of process design |
| Strict output schemas | Agents have judgment, rigid formats constrain usefulness |
| Separate documentation phase | Integrates better as part of implementation |

---

## Trade-offs Accepted

| Trade-off | Upside | Downside |
|-----------|--------|----------|
| Agent autonomy | Less micromanagement, faster flow | Occasional misjudgment |
| Merged analyst | Simpler handoffs | Heavy single agent |
| Reviewer fixes directly | Faster resolution | Reviewer does more work |
| Two-level hierarchy | Simple mental model | Can't represent deep nesting |
| Sequential only | Clear ownership | Slower for parallelizable work |
| Implementer autonomy | Can remedy upstream gaps | Might deviate unnecessarily |
| Business-aware analyst | Better requirement validation | Slightly longer analysis phase |

---

## Future Evolution Points

When to revisit these decisions:

1. **Analyst too slow:** Split into "validate" (fast requirements check) and "specify" (interactive detailed spec)

2. **Implementer deviating too much:** Tighten autonomy, require master consultation for more cases

3. **Lessons-learned getting stale:** Add periodic review, prune outdated entries

4. **Need parallelism:** Add dependency tracking between sub-tasks, let master dispatch multiple agents

5. **Need approval gates:** Add `PENDING_APPROVAL` status, master waits for human before proceeding

6. **More artifact types:** Extend registry schema with `scope` (which agents) or `format` (how to parse)

7. **Cross-project learning:** Extract lessons-learned to shared location, planner checks project + global

---

## Summary

**This workflow optimizes for:**
- Due process without bureaucracy
- Speed for simple stuff
- Business-aware analysis (40/60 business/technical)
- Enabling, not prescribing
- Thinking implementer with safety valve
- Closed learning loop
- Distributed documentation

**It deliberately avoids:**
- Over-specification (agents have judgment)
- Deep hierarchies (two levels max)
- Approval bottlenecks (interrupt, don't approve each step)
- Automatic recovery (blocked = human decides)
- Separate documentation phase (integrated)

**The core philosophy:** Add structure where it helps (task tracking, artifact awareness, handoff contracts) while trusting AI agents to think, adapt, and improve.