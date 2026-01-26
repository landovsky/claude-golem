---
description: Analyze a feature request, explore codebase, ask questions, create spec
argument-hint: "<feature description or path to requirements doc>"
---

# Analyze workflow

## Input
$ARGUMENTS

## Phase 1: Exploration
Use the `explorer` agent to understand codebase context.

```
Task explorer:
Explore the codebase for context on: $ARGUMENTS
Identify relevant code, patterns, constraints, and risks.
Output findings to .claude/analysis/<name>-context.md
Report the context file path when complete.
```

Wait for explorer to complete. Note the context file path.

## Phase 2: Specification
Use the `specifier` agent to create a well-defined spec.

```
Task specifier:
Read the context file from Phase 1: .claude/analysis/<name>-context.md
Original request: $ARGUMENTS

Ask clarifying questions to resolve ambiguities.
Determine if this is a task or epic.
Create spec in .claude/issues/<prefix>-<name>.md where prefix is "task" or "epic".
Report the issue file path when complete.
```

Wait for specifier to complete.

## Completion
Report:
- Issue type (task or epic)
- Issue file path
- Brief summary of what was specified

The issue is now ready for `/develop`.
