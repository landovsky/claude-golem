---
description: Document learnings from current session into conventional document in current project
argument-hint: "<optional: specific topic or area to focus on>"
---

# Document Session Learnings

You are a reflective practitioner. Your job is to review the current conversation, extract valuable learnings, and append them to the project's lessons-learned document.

## Input

$ARGUMENTS

## Instructions

### 1. Find the lessons-learned file

Check for an existing lessons-learned document in the current project:

```bash
# Check common locations in order of preference
for f in artifacts/lessons-learned.md docs/lessons-learned.md LESSONS-LEARNED.md; do
  if [ -f "$f" ]; then echo "FOUND: $f"; break; fi
done
```

If no file exists, use `artifacts/lessons-learned.md` as the default location (create `artifacts/` directory if needed). Set a flag `CREATED_NEW=true` if you created a new file.

### 1b. Register new artifact in CLAUDE.md

If `CREATED_NEW=true`, register the lessons-learned file in the project's `CLAUDE.md`:

1. Find the local `CLAUDE.md` (check working directory, not `~/.claude/CLAUDE.md`)
2. Look for an existing `## Artifacts` section with a markdown table
3. If the section and table exist, append a row:
   ```
   | `<relative-path>` | Accumulated learnings from completed work — what worked, what to avoid, process improvements |
   ```
4. If no `## Artifacts` section exists, append this block to the end of `CLAUDE.md`:
   ```markdown

   ## Artifacts

   Read relevant artifacts before progressing with user's request. Update them when decisions change or new, substantial details emerge.

   | Artifact | Description |
   |----------|-------------|
   | `<relative-path>` | Accumulated learnings from completed work — what worked, what to avoid, process improvements |
   ```
5. If no `CLAUDE.md` exists, skip this step silently.

### 2. Review the session

Analyze the full conversation history. Look for:

- **What worked well** — approaches, tools, patterns, or decisions that led to good outcomes
- **What to avoid** — mistakes, dead ends, wrong assumptions, or things that wasted time
- **Process improvements** — changes to workflow, checklists, or habits that would help future work

If the user provided a topic focus in the arguments, narrow your review to that area.

### 3. Determine the entry heading

Use this format: `## YYYY-MM-DD - <concise description of the work done>`

The description should capture the main task or theme (e.g., "Docker multi-stage build optimization", "Auth flow refactoring", "K8s sidecar debugging").

### 4. Write the entry

Append a new section to the lessons-learned file using this structure:

```markdown
## YYYY-MM-DD - <description>

### What worked well
- **Bold key insight**: Explanation with specifics (file names, line numbers, tool names)

### What to avoid
- **Bold the trap**: What went wrong and why, with concrete details so future readers recognize the pattern

### Process improvements
- **Bold the recommendation**: Actionable change to prevent the issue or replicate the success
```

### 5. Quality checks

Before writing, verify each lesson:

- **Is it specific?** — Mentions concrete files, tools, patterns, or error messages (not vague platitudes)
- **Is it actionable?** — A future reader can DO something different based on this
- **Is it novel?** — Not already captured in the existing lessons-learned file
- **Is it durable?** — Will still be relevant in a month (not session-specific trivia)

Drop any lesson that fails these checks. It's better to write 2 solid lessons than 6 weak ones.

### 6. Confirm

After writing, report:

```
Documented N learnings to <file-path>:
- <one-line summary of each learning>
```

## Rules

- Do NOT invent learnings — only capture what actually happened in this session
- Do NOT duplicate existing entries — read the file first and skip anything already covered
- Do NOT include session-specific details (task IDs, branch names) unless they illustrate a general pattern
- Do NOT ask clarifying questions — use your judgment to extract the most valuable insights
- Keep entries concise — aim for 3-6 bullet points per section, skip empty sections
- If the session had no meaningful learnings, say so honestly instead of forcing weak entries
- Match the tone and detail level of existing entries in the file
