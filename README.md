# AI Development Workflow

A structured workflow for AI-assisted development that ensures due process (specify → plan → implement → review) while not over-processing simple tasks.

## The Problem

When using AI for development, you face a tension:
- **Too little process**: AI dives straight into coding, misses requirements, creates technical debt
- **Too much process**: Every typo fix goes through a full analysis cycle, wasting time

This workflow adds structure where it helps while trusting AI agents to think, adapt, and improve.

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                         MASTER                               │
│  Assesses complexity, decides path, manages task lifecycle   │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              │                               │
       ┌──────▼──────┐               ┌───────▼───────┐
       │ FAST-TRACK  │               │ FULL WORKFLOW │
       │  (simple)   │               │   (complex)   │
       └─────────────┘               └───────────────┘
                                              │
                    ┌─────────────────────────┼─────────────────────────┐
                    │                         │                         │
             ┌──────▼──────┐          ┌──────▼──────┐          ┌───────▼───────┐
             │   ANALYST   │          │   PLANNER   │          │  IMPLEMENTER  │
             │  40% biz    │    →     │  context &  │    →     │   autonomy    │
             │  60% tech   │          │  warnings   │          │ + safety valve│
             └─────────────┘          └─────────────┘          └───────────────┘
                                                                        │
                                                               ┌────────▼────────┐
                                                               │    REVIEWER     │
                                                               │ triage & fix    │
                                                               └─────────────────┘
```

### Agents

| Agent | Purpose |
|-------|---------|
| **Master** | Assesses requests, routes to fast-track or full workflow, handles escalations |
| **Analyst** | Explores codebase, validates requirements fit, produces specifications |
| **Planner** | Provides context and warnings for implementer (not prescriptive instructions) |
| **Implementer** | Implements with autonomy, can remedy upstream gaps, consults master if off-course |
| **Reviewer** | Triages issues: fixes critical/major directly, documents minor |

### Task Tracking

Uses `bd` (Beads) - a git-backed issue tracker. Tasks have sub-tasks representing workflow stages:

```
task-123 (parent)
├── task-123.1 (analyze)
├── task-123.2 (plan)
├── task-123.3 (implement)
└── task-123.4 (review)
```

If analyst determines scope is too large, the task becomes an epic with child tasks. Children skip analyst (already scoped) and start at planner:

```
epic-456 (converted from task)
├── task-457 (child) → planner → implementer → reviewer
└── task-458 (child) → planner → implementer → reviewer
```

### Usage

```bash
# Start development workflow
/develop <task description>

# Quick capture without starting development
/bd-task <task description>
```

## Design Philosophy

**Optimizes for:**
- Due process without bureaucracy
- Speed for simple stuff
- Business-aware analysis
- Enabling, not prescribing
- Closed learning loop (lessons-learned.md)

**Avoids:**
- Over-specification (agents have judgment)
- Deep hierarchies (two levels max)
- Approval bottlenecks
- Automatic recovery (blocked = human decides)

## Known Problems

### Critical

1. **Inconsistent input sources** - Planner's Input section lists file path as primary source, but Phase 1 says bd comments are primary. Agents may look in wrong place for upstream output.

2. **Missing agent invocation protocol** - Master describes what task IDs to pass to agents but not HOW to invoke them. No syntax or mechanism defined.

### Major

1. **Inconsistent fallback behavior** - Input sections contradict Phase 1 instructions across agents
2. **Unclear ID naming** - Analyst uses `[own-task-id]` for comments but `[issue-id]` for closing
3. **Undocumented bd commit semantics** - No agent shows bd commit command
4. **Vague validation criteria** - Master validation doesn't specify what constitutes valid output

### Minor

1. **Optional vs expected output** - Implementer bd comment is optional but master expects to validate it
2. **Inconsistent variables** - `[issue-id]` vs `[own-task-id]` vs `[task-id]` used interchangeably
3. **Format inconsistency** - Reviewer Phase 1 mixes comment-in-code-block format

See [.claude-2uo](command:bd%20show%20.claude-2uo) for full details and recommendations.

## Installation

This repository IS the `~/.claude/` directory. Clone it directly:

```bash
# Back up existing config if needed
mv ~/.claude ~/.claude.backup

# Clone this repo as your Claude config
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git ~/.claude
```

Runtime files (MCP logs, session data, project caches) are gitignored - only workflow configuration is tracked.

### Prerequisites

Install the `bd` CLI for task tracking:

```bash
curl -sSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash
```

## Files

```
~/.claude/
├── agents/
│   ├── master.md      # Orchestrator
│   ├── analyst.md     # Specification
│   ├── planner.md     # Context preparation
│   ├── implementer.md # Code changes
│   └── reviewer.md    # Quality & lessons
├── commands/
│   ├── develop.md     # Full workflow command
│   └── bd-task.md     # Quick capture command
└── artifacts/
    └── workflow-design/
        └── WORKFLOW-DESIGN-RATIONALE.md
```

## License

MIT
