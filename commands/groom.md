---
description: Groom GitHub issues — analyze codebase, identify open questions, check dependencies, prepare specs for implementation. Use when issues are labeled 'for-grooming' or when the user wants to prepare raw requirements for development.
argument-hint: "<issue number, 'all' for all for-grooming issues, or topic to filter by>"
---

# Issue Grooming

Prepare raw GitHub issues for implementation. A groomed issue gives the implementer everything they need to start work without guessing.

## Input

$ARGUMENTS

- Number → groom that issue
- `all` → all issues labeled `for-grooming`
- Topic → `for-grooming` issues matching that topic

## Label Lifecycle

| Label | Actor | Meaning |
|-------|-------|---------|
| `for-grooming` | Claude | Raw requirement, needs analysis |
| `needs-input` | Human | Analyzed, has open questions |
| `ready` | Claude | Spec complete, implementable |
| `review` | Human | Implemented, needs verification |

Grooming moves an issue from `for-grooming` → `needs-input` (or straight to `ready` if no questions arise).

## What a groomed issue looks like

A well-groomed issue answers three questions:
1. **Why** does this change matter? What problem does it solve, who benefits, what's the motivation?
2. **What** exists today and what needs to change? Grounded in specific code, not abstractions.
3. **What's unclear?** Questions where the answer changes the implementation approach.

### Issue description structure

```markdown
## Why
[The motivation — what problem this solves, who it helps, what's painful about the current state.
Preserve original context (meeting notes, user quotes) that conveys intent.]

## Current state
[What exists in code today — specific file paths, models, associations, relevant behavior.]

## What needs to change
[Clear description of the desired end state.]

## Open questions
- [ ] **Q1: [topic]** — [question where the answer affects implementation]

## Dependencies
- **Depends on:** [issues that must land first, or "none"]
- **Relates to:** [issues touching similar code]
- **Blocked by:** [external blockers or "nothing"]
```

## How grooming works

For each issue, a analyst (Sonnet model) agent explores the codebase on the correct branch, reads the relevant code, and produces the updated issue description. When grooming multiple issues, agents run in parallel.

Each agent receives:
- The full issue body
- Sibling issue numbers and titles (for dependency checking)
- The base branch to analyze

## Communication

All communication happens through the **issue description** (not comments — those appear as the user's identity). Labels signal whose turn it is to act.

## Principles

- **Motivation first** — a requirement without a "why" is a guess. Surface the purpose even if the original issue didn't state it explicitly. Use meeting context, domain docs, or the code itself to infer why this matters.
- **Grounded in code** — reference specific files, models, and associations. Vague analysis ("the view needs updating") is not useful.
- **Questions that matter** — only surface questions where the answer genuinely changes the implementation approach. Anything decidable during implementation is not worth asking.
- **Preserve original context** — don't lose information from the raw issue. Meeting quotes, user language, and domain terms carry intent that formal rewrites often drop.
- **No scope creep** — describe what was asked for, not what could be improved nearby.
