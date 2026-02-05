# AI Development Workflow

A structured workflow for AI-assisted development that ensures due process (specify → plan → implement → review) while not over-processing simple tasks. Includes optional isolated sandbox environments for autonomous execution.

## Table of Contents

- [The Problem](#the-problem)
- [How It Works](#how-it-works)
  - [Agents](#agents)
  - [Task Tracking](#task-tracking)
  - [Commands](#commands)
- [Sandbox Execution](#sandbox-execution)
- [Design Philosophy](#design-philosophy)
- [Known Problems](#known-problems)
- [Artifacts System](#artifacts-system)
  - [Structure](#structure)
  - [Registry Format](#registry-format)
  - [How Agents Use Artifacts](#how-agents-use-artifacts)
  - [The Learning Loop](#the-learning-loop)
  - [Creating Custom Artifacts](#creating-custom-artifacts)
- [Installation](#installation)
  - [Prerequisites](#prerequisites)
- [Files](#files)
- [License](#license)

## The Problem

When using AI for development, you face a tension:
- **Too little process**: AI dives straight into coding, misses requirements, creates technical debt
- **Too much process**: Every typo fix goes through a full analysis cycle, wasting time

This workflow adds structure where it helps while trusting AI agents to think, adapt, and improve.

**See [Design Rationale](artifacts/workflow-design/WORKFLOW-DESIGN-RATIONALE.md) for the full reasoning behind these decisions.**

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                   MASTER (/develop)                          │
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

If analyst determines scope is too large, the task becomes an epic with child tasks:

```
epic-456 (converted from task)
├── task-457 (child) → planner → implementer → reviewer
└── task-458 (child) → planner → implementer → reviewer
```

### Commands

```bash
# Start development workflow (primary command)
/develop <task description or beads ID>
# Assesses complexity, routes to fast-track or full workflow,
# creates and manages beads tasks/subtasks

# Quick task capture
/bd-task <task description>
# Capture work without starting implementation

# Other commands
/validate    # Organize and validate ideas before committing to work
/debug       # Generate debugging hypotheses
/keybindings-help  # Customize keyboard shortcuts
```

### Usage Tracking (Experimental)

The `/develop` workflow automatically tracks token usage, costs, and duration for each stage (analyst, planner, implementer, reviewer). Data is persisted to `.claude/workflow-metrics.jsonl` and posted as beads comments.

**Use cases:**
- Benchmark workflow overhead vs fast-track implementation
- Detect token anomalies and investigate inefficiencies
- Understand which stages consume the most resources

**See [artifacts/usage-metrics/README.md](artifacts/usage-metrics/README.md) for setup and usage.**

**Status:** Experimental - real token data collection working, but requires manual settings.json configuration per user.

## Sandbox Execution

For autonomous, unsupervised execution, use the included **claude-sandbox** environment:

**What it provides:**
- Isolated Docker/Kubernetes execution environment
- Fresh git clone per run (doesn't touch your local checkout)
- Full stack: PostgreSQL, Redis, Chrome for system tests
- Protected branches (prevents force-push to main/master/production)
- Telegram notifications when tasks complete or fail
- Encrypted secrets management (SOPS) for project-specific config
- Auto-detection of repository and branch from current directory

**Use cases:**
- Run Claude autonomously while you sleep or work on other things
- Execute tasks on remote k8s cluster with same environment
- Safely test changes in isolation before applying locally
- Run multiple tasks in parallel on different projects

**Quick start:**
```bash
# Local execution
cd ~/your-project
~/.claude/claude-sandbox/bin/claude-sandbox local "run database migrations"

# Remote execution (k8s)
cd ~/your-project
~/.claude/claude-sandbox/bin/claude-sandbox remote "implement feature X"
```

**See [claude-sandbox/README.md](claude-sandbox/README.md) for complete setup and usage guide.**

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


## Artifacts System

Project-specific guidance and accumulated learnings live in `artifacts/` directory. This provides a knowledge base that agents consult and update during development.

### Structure

```
artifacts/
  registry.json                  # Lists available artifacts
  lessons-learned.md            # Accumulated learnings from past work
  workflow-design/              # Workflow documentation
    WORKFLOW-DESIGN-RATIONALE.md
    WORKFLOW.md
```

### Registry Format

Artifacts are registered in `artifacts/registry.json`:

```json
[
  {
    "filename": "lessons-learned.md",
    "description": "Accumulated learnings from past work to avoid repeated mistakes",
    "usage": "always"
  },
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
3. **Planner** lists which artifacts implementer must follow (and reads lessons-learned before every plan)
4. **Implementer** follows artifact guidance, updates artifacts if spec requires
5. **Reviewer** verifies artifact compliance and updates, writes to lessons-learned

### The Learning Loop

The reviewer captures lessons from completed work in `artifacts/lessons-learned.md`. The planner reads this file before every plan to avoid repeated mistakes. This creates a closed feedback loop where past experience directly improves future work.

### Creating Custom Artifacts

Add project-specific guidance (coding standards, architecture decisions, business processes) as markdown files in `artifacts/` and register them in `registry.json`. Agents will automatically discover and use them.

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
│   ├── validate.md    # Idea validation workflow
│   ├── develop.md     # Full development workflow
│   ├── bd-task.md     # Quick task capture
│   ├── debug.md       # Debugging hypotheses
│   └── keybindings-help.md  # Keyboard customization
├── claude-sandbox/    # Isolated execution environment
│   ├── README.md      # Sandbox documentation
│   ├── Dockerfile     # Container image
│   ├── bin/           # CLI tools
│   └── k8s/           # Kubernetes templates
└── artifacts/
    ├── registry.json           # Artifact registry
    ├── lessons-learned.md      # Learning loop
    ├── ideas/                  # Discovery workflow
    │   ├── scratch/            # Raw ideas (git-ignored)
    │   ├── analysis/           # Documented challenge analysis
    │   └── README.md           # Ideas directory guide
    └── workflow-design/        # Workflow docs
        ├── WORKFLOW-DESIGN-RATIONALE.md
        ├── WORKFLOW.md
        └── DISCOVERY.md        # Idea validation process
```

## License

MIT
