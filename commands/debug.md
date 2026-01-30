---
description: Generate debugging hypotheses for unexpected behavior
argument-hint: "<description of unexpected behavior, error messages, stack traces>"
model: opus
---

# Debug Hypothesis Generator

You analyze unexpected behavior and produce structured debugging hypotheses. Your goal is to save debugging time by identifying the most likely causes and providing concrete ways to test each one.

## Input

A description of unexpected behavior, which may include:
- What was expected vs. what actually happened
- Error messages or stack traces
- Recent changes that might be related
- Environmental context (OS, versions, etc.)

$ARGUMENTS

## Phase 1: Parse the Problem

Extract and organize the key information:

1. **Symptom**: What exactly is happening? (observable behavior)
2. **Expected**: What should happen instead?
3. **Context**: When/where does it occur? (always, sometimes, specific conditions)
4. **Error signals**: Any error messages, codes, or stack traces
5. **Timeline**: When did it start? What changed recently?

If critical information is missing, note what would help narrow down the cause.

## Phase 2: Generate Hypotheses

Produce 3-5 hypotheses ranked by likelihood. For each hypothesis:

```markdown
### Hypothesis [N]: [Brief title]

**Likelihood:** [High|Medium|Low]

**Theory:** [1-2 sentences explaining the suspected cause]

**Supporting evidence:**
- [What in the problem description points to this]

**Contradicting evidence:**
- [What argues against this, if anything]

**How to test:**
1. [Specific, actionable step to confirm or rule out]
2. [Additional verification if needed]

**If confirmed, offer to:**
- fix it
- create a task using /bd-task
```

## Phase 3: Suggest Investigation Order

Provide a recommended debugging sequence.

## Output Format

Save as a file.

```markdown
# Debug Analysis: [Brief problem summary]

## Problem Summary
[Parsed understanding of the issue]

## Missing Information
[What additional context would help, if any]

## Hypotheses

### Hypothesis 1: [Title]
[Full hypothesis block]

### Hypothesis 2: [Title]
[Full hypothesis block]

[... more hypotheses ...]

## Recommended Investigation Order
[Prioritized list with reasoning]

## Quick Wins
[Fast checks to try first]

## Need More Info?
[What to do if hypotheses don't pan out]

```
