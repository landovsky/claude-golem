# AI Development Workflow Documentation

A lightweight workflow for AI-assisted software development. Ensures due process while allowing fast-tracking of simple tasks.

## Quick Reference

```
Request → Master assesses → Simple? → Fast-track (master handles end-to-end)
                         → Complex? → Analyst → Planner → Implementer → Reviewer
```

## Terminology

| Term | Definition |
|------|------------|
| **Issue** | Any item in bd (task or epic) |
| **Task** | A single unit of work |
| **Sub-task** | A workflow stage within a task (e.g., `task-123.1-analyze`) |
| **Epic** | A collection of dependent tasks |

## Agents

| Agent | Role | Focus |
|-------|------|-------|
| **Master** | Orchestrates workflow, assesses requests, handles escalations | Decision-making |
| **Analyst** | Explores codebase, validates requirements fit, writes specs | 40% business, 60% technical |
| **Planner** | Prepares context to help implementer succeed | Enabling, warning, guiding |
| **Implementer** | Writes code with judgment, remediates upstream gaps | Thinking, not just executing |
| **Reviewer** | Reviews, fixes critical issues, captures lessons | Quality and learning |

## Task Structure

All work tracked in `bd`:

```
task-123                    # Simple task (master handles)

task-456                    # Complex task
  task-456.1-analyze        # Sub-task for analyst
  task-456.2-plan           # Sub-task for planner
  task-456.3-implement      # Sub-task for implementer
  task-456.4-review         # Sub-task for reviewer

epic-789                    # Epic (depends on tasks)
  → depends on task-790
  → depends on task-791
```

**If analyst needs to split:** Convert original task to epic, create dependent tasks.

## Workflow Paths

### Fast-Track (Simple Tasks)

Master owns end-to-end:
1. Creates single task in bd
2. Implements directly
3. Runs quality gates
4. Marks complete

**Criteria for fast-track:**
- Single file or function scope
- Uses existing patterns unchanged
- Low risk, easily reversible
- Clear requirements

### Full Workflow (Complex Tasks)

Sequential handoff with increasing autonomy:

1. **Master** creates task + sub-tasks
2. **Analyst** validates requirements, explores fit, writes spec
3. **Planner** prepares context, warnings, patterns for implementer
4. **Implementer** builds with judgment, remediates gaps, consults master if off-course
5. **Reviewer** verifies, fixes critical/major, captures lessons

## Documentation Responsibility

There is no separate "documenter" agent. Documentation is distributed:

| Who | What |
|-----|------|
| **Analyst** | Identifies which artifacts need updating in the spec |
| **Planner** | Assigns documentation work to implementer in the plan |
| **Implementer** | Updates documentation alongside code |
| **Reviewer** | Verifies documentation was updated, captures lessons-learned |

If a business process changes, the artifact documenting it must change too. This is tracked as a deliverable, not an afterthought.

## The Learning Loop

```
.claude/lessons-learned.md
         ↑
    Reviewer writes
         │
         ↓
    Planner reads
         │
         ↓
    Future plans include warnings based on past mistakes
```

Lessons-learned is not a graveyard - it's actively consumed by the planner to improve future work.

## Artifacts System

Project-specific guidance lives in `artifacts/`:

```
artifacts/
  registry.json           # Lists available artifacts
  ui-style-guide.md       # Example artifact
```

### Registry Format

```json
[
  {
    "filename": "ui-style-guide.md",
    "description": "Visual design standards for UI components",
    "usage": "decide"
  }
]
```

**Usage values:**
- `always` - Agent must consult this artifact
- `decide` - Agent determines relevance based on task

### How Agents Use Artifacts

1. **Master** reads registry, passes relevant artifacts to agents
2. **Analyst** curates: reads, extracts relevant bits, flags if artifact needs updating
3. **Planner** lists which artifacts implementer must follow
4. **Implementer** follows artifact guidance, updates artifacts if spec requires
5. **Reviewer** verifies artifact compliance and updates

## File Outputs

```
.claude/
  analysis/
    [issue-id]-context.md   # Analyst's exploration findings
  specs/
    [issue-id]-spec.md      # Analyst's specification
  plans/
    [issue-id]-plan.md      # Planner's implementation context
  lessons-learned.md        # Reviewer's accumulated learnings (read by planner)
```

## Blocked Handling

When an agent blocks:
1. Agent marks sub-task blocked with reason
2. Master detects blocked status
3. Master proposes solution to human
4. Human decides, master unblocks

No silent failures - blocked = human notified with proposed solution.

## Implementer Safety Valve

The implementer has autonomy but a safety valve:

**Consult master when:**
- Significantly changing the approach
- Discovered unanticipated blocker
- Scope growing beyond "one task"
- Something feels wrong

**Don't consult for:**
- Normal implementation decisions
- Small pattern adaptations
- Sensible edge case handling

## Key Principles

1. **Due process without bureaucracy** - complex tasks get analyzed, planned, implemented, reviewed
2. **Fast-track for simple stuff** - typo fixes don't need full ceremony
3. **Business-first analysis** - understand "why" before "how"
4. **Enabling, not prescribing** - planner gives context, implementer decides
5. **Thinking implementer** - capable of remediating upstream gaps
6. **Learning accumulation** - lessons-learned grows and feeds future planning
7. **Distributed documentation** - no separate documenter, everyone contributes

## Human Intervention Points

- After master assessment (can override simple/complex decision)
- During analyst clarification (answering questions)
- When any agent blocks (resolving blockers)
- When implementer consults master (direction needed)

## Getting Started

1. Copy `agents/` to your project or reference globally
2. Create `artifacts/registry.json` (can be empty array initially)
3. Add project-specific artifacts as needed
4. Invoke master with your request

## Customization

### Add New Artifact Type

1. Create `artifacts/[name].md`
2. Add entry to `artifacts/registry.json`
3. Agents discover it automatically

### Modify Agent Behavior

Each agent is in `agents/[name].md`. Key calibration points:
- Analyst: business/technical balance (currently 60/40)
- Planner: depth of warnings and context
- Implementer: autonomy level, when to consult
- Reviewer: triage thresholds for critical/major/minor