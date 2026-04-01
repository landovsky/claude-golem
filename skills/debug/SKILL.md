---
name: debug
description: Generate structured debugging hypotheses when the user is stuck on a bug, has tried multiple fixes that didn't work, or wants to step back and analyze a problem systematically before jumping to solutions. Use this skill whenever the user says things like "this still doesn't work", "I've tried everything", "let's think about this differently", "why is this happening", or when you notice repeated failed fix attempts in the conversation. Also use it when the user describes unexpected behavior with error messages or stack traces and hasn't started debugging yet.
user-invocable: true
argument-hint: <description of unexpected behavior, error messages, stack traces>
---

# Debug Hypothesis Generator

You analyze unexpected behavior and produce structured debugging hypotheses. Your purpose is to prevent wasted time from jumping to conclusions — instead, you map out the most likely causes and how to test each one before writing any fix.

## When this skill activates

This skill is most valuable when:
- A fix has been attempted and failed (Claude or the user tried something that didn't work)
- The root cause is unclear and multiple explanations are plausible
- The user wants to think before acting

The key discipline: **generate hypotheses first, test them second, fix last.** Resist the urge to start writing code.

## Input

A description of unexpected behavior, which may include:
- What was expected vs. what actually happened
- Error messages or stack traces
- Recent changes that might be related
- Environmental context (OS, versions, etc.)

$ARGUMENTS

## Phase 1: Parse the Problem

Extract and organize:

1. **Symptom**: What exactly is happening? (observable behavior)
2. **Expected**: What should happen instead?
3. **Context**: When/where does it occur? (always, sometimes, specific conditions)
4. **Error signals**: Any error messages, codes, or stack traces
5. **Timeline**: When did it start? What changed recently?
6. **Prior attempts**: What has already been tried and why it didn't work

If critical information is missing, note what would help narrow down the cause.

## Phase 2: Generate Hypotheses

Produce 3-5 hypotheses ranked by likelihood. The point is to consider the problem from multiple angles — not just the most obvious cause. Include at least one hypothesis that challenges an assumption everyone has been making.

For each hypothesis:

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
```

## Phase 3: Investigation Order

Provide a recommended debugging sequence that optimizes for:
- Fastest to test first (quick checks before deep dives)
- Most likely causes before unlikely ones
- Non-destructive checks before changes

## Output

Present the analysis directly in the conversation. Keep it scannable — the user needs to quickly pick which hypothesis to investigate first, not read an essay.
