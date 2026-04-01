---
description: Document learnings from current session into memory-store
argument-hint: "<optional: specific topic or area to focus on>"
---

# Document Session Learnings

You are a reflective practitioner. Review the current conversation, extract valuable learnings, and store them in memory-store for future sessions.

## Input

$ARGUMENTS

## Instructions

### 1. Review the session

Analyze the full conversation history. Look for:

- **What worked well** — approaches, tools, patterns, or decisions that led to good outcomes
- **What to avoid** — mistakes, dead ends, wrong assumptions, or things that wasted time
- **Non-obvious decisions** — trade-offs, workarounds, or choices that would surprise a future reader

If the user provided a topic focus, narrow your review to that area.

### 2. Quality-check each learning

Before storing, verify each lesson:

- **Specific** — mentions concrete files, tools, patterns, or error messages (not vague platitudes)
- **Actionable** — a future session can DO something different based on this
- **Novel** — not already in memory-store (search first)
- **Durable** — will still be relevant in a month (not session-specific trivia)

Drop any lesson that fails these checks. 2 solid learnings beat 6 weak ones.

### 3. Search for existing related memories

Before adding, query memory-store to avoid duplicates:

```
mcp__memory-store__search_memory_facts — search for each topic you plan to store
```

If a related memory exists, update it (delete old + add new) rather than creating a duplicate.

### 4. Store learnings

Use `mcp__memory-store__add_memory` for each learning. Structure the content as:

```
source: <what happened>
content: <the learning — what worked, what to avoid, or what to do differently>
```

Scope with `group_id`:
- Project-specific learnings → `group_id: "<project-name>"` (derive from working directory)
- Cross-project learnings (tool usage, workflow habits) → `group_id: "global"`

### 5. Confirm

After storing, report:

```
Stored N learnings to memory-store:
- <one-line summary of each>
```

## Rules

- Do NOT invent learnings — only capture what actually happened in this session
- Do NOT duplicate existing memories — search first, update if related memory exists
- Do NOT store ephemeral details (task IDs, branch names) unless they illustrate a general pattern
- Do NOT ask clarifying questions — use your judgment to extract the most valuable insights
- If the session had no meaningful learnings, say so honestly instead of forcing weak entries
