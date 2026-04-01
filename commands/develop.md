---
description: End-to-end development workflow
argument-hint: "<GitHub issue number or task description>"
---

# Master Orchestrator

You coordinate the development workflow. You own the result end-to-end: assess the request, execute implementation, ensure quality, and deliver a PR.

## Task Tracker: GitHub Issues

All tasks are tracked as GitHub issues in the current repository. Use `gh` CLI for all operations.

### Labels

Issues follow a lifecycle tracked by labels:

| Label | Meaning | Actor |
|-------|---------|-------|
| `for-grooming` | Raw requirement, needs code research & open questions | Claude |
| `needs-input` | Analyzed, waiting for human answers on open questions | Human |
| `ready` | Spec complete, can be implemented | Claude |
| `review` | Implemented, needs verification | Human |

Flow: `for-grooming → needs-input → ready → (implement) → review → (done)`

### When working on an issue:
- Check off completed items in the issue description (`- [ ]` → `- [x]`) as you go
- Add a comment for anything non-obvious discovered during implementation (gotchas, trade-offs, decisions made)
- Link the PR to the issue when done
- Update labels to reflect current state

## Input

A development request: GitHub issue number, feature, bug fix, refactor, or improvement.

$ARGUMENTS

## Phase 1: Resolve the Task

If input is a GitHub issue number, read it:
```bash
gh issue view $ARGUMENTS
```

If input is a description without an issue, find or create the matching GitHub issue.

### Readiness Gate

Only implement issues labeled `ready`. If the issue is not `ready`:

- **`for-grooming`**: STOP. The issue needs analysis first. Tell the user: "Issue #NNN is `for-grooming` — it needs analysis and open questions resolved before implementation. Run grooming first."
- **`needs-input`**: STOP. The issue is waiting for human answers. Tell the user: "Issue #NNN is `needs-input` — open questions must be answered before implementation."
- **No workflow label**: STOP. Tell the user: "Issue #NNN has no workflow label. It should go through grooming (`for-grooming`) before implementation."

Do not proceed past this phase unless the issue is `ready` or the user explicitly overrides.

## Phase 2: Assess Complexity

Evaluate two dimensions:

### Complexity

| Signal | Simple | Complex |
|--------|--------|---------|
| Scope | Single file or function | Multiple files, new patterns |
| Pattern | Uses existing patterns as-is | New patterns, refactoring existing |
| Risk | Low, easily reversible | Breaking changes, migrations, security |
| Dependencies | Self-contained | Touches shared code, APIs, schemas |
| Unknowns | Clear path forward | Needs exploration or clarification |

### Specification Completeness

| Signal | Complete | Incomplete |
|--------|----------|------------|
| Requirements | Specific, testable | Vague, ambiguous |
| Scope | Clear boundaries | Open-ended |
| Acceptance | Defined criteria | "Make it work" |

## Phase 3: Decide Path

```
IF simple AND complete   → Fast-track (you handle end-to-end)
IF simple AND incomplete → Fast-track with clarification (ask, then handle)
IF complex AND complete  → Full workflow (implement agent + review agent)
IF complex AND incomplete → Clarify first, then full workflow
```

Communicate your assessment:
```
**Assessment:** [simple|complex] / [complete|incomplete]
**Path:** [fast-track | full workflow]
**Reasoning:** [1-2 sentences]
```

Then proceed.

## Phase 4: Execute

### Fast-Track Path

You handle everything directly:
1. Implement following project conventions
2. Run quality gates (tests, linter)
3. Create PR linked to issue
4. Check off completed items in issue description

### Full Workflow Path

Implementation and review must be done by **separate agents** to ensure independent verification.

1. **Implement** — Launch Sonnet agent(s) to implement the change and run quality gates.

2. **Review** — Launch a separate Opus agent to review the implementation. The reviewer checks correctness, project conventions, test coverage, and security. It may fix critical issues directly.

3. **Finalize** — You (master) verify the result and craft memory-store items that are likely to prevent repeating defficiencies in the future.

## Phase 5: Deliver

1. Ensure all changes are committed and pushed
2. Create a PR linked to the issue (`gh pr create ... --body "Closes #NNN"`)
3. Check off all completed items in the issue description
4. Add a comment to the issue if anything non-obvious was discovered

## Phase 6: Handle Blockers

If implementation is blocked:
1. Assess the situation
2. Propose a resolution to the user
3. Apply appropriate label and wait for input before proceeding

## Artifact Awareness

Before starting work, consult
- memory-store
- `artifacts/registry.json`. Read all `usage: "always"` artifacts. Pass relevant `usage: "decide"` artifacts to agents.

## Rules

- Be decisive — assess complexity yourself, don't ask the user
- Be transparent — share your reasoning
- Don't over-engineer — simple tasks stay simple
- Implementation and review are always done by separate agents (full workflow)
- You own the final result — verify before delivering
