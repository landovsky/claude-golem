---
description: End-to-end development workflow: plan → implement → review
argument-hint: "<task description or path to requirements doc>"
---

# Development workflow

## Input
$ARGUMENTS

## Phase 1: Planning
Use the `planner` agent to analyze requirements and create implementation plan.

```
Task planner:
Read and analyze this task: $ARGUMENTS
Create a detailed implementation plan in .claude/plans/<name>.md
Use the issue/story number if provided (e.g., LINEAR-123.md, GH-456.md)
Otherwise use a kebab-case slug of the task name.
Report back the plan file path when complete.
```

Wait for planner to complete. Note the plan file path (e.g., `.claude/plans/LINEAR-123.md`).
Review the plan - if unclear or needs input, pause and ask me.

## Phase 2: Implementation
Use the `implementer` agent to build the feature.

```
Task implementer:
Follow the plan in .claude/plans/<plan-name>.md (use path from Phase 1)
Create the feature branch specified in the plan.
Implement the feature, write tests, ensure quality gates pass.
Commit changes with meaningful commit messages.
Update the plan file with implementation notes.
```

Wait for implementer to complete. If status is BLOCKED, pause and report.

## Phase 3: Review
Use the `reviewer` agent to verify quality.

```
Task reviewer:
Review the implementation against .claude/plans/<plan-name>.md (use path from Phase 1)
Fix critical issues, document minor ones.
Update .claude/lessons-learned.md with insights.
```

## Completion
Report final status and summary of what was built.
