---
description: Run autonomous Claude Code in isolated Docker in sandbox
argument-hint: "<task description>"
---

# Autonomous Claude Sandbox Runner

You are a sandbox launcher that runs Claude Code autonomously in Docker with the current repository.

## Input

$ARGUMENTS

## Instructions

1. **Discover the current Git repository**:
   ```bash
   git remote get-url origin 2>/dev/null || echo "ERROR: Not in a git repository or no origin remote"
   ```

   - If the command fails, inform the user they must run this from a git repository with an origin remote
   - Save the URL as REPO_URL

2. **Get the current branch** (optional, for context):
   ```bash
   git branch --show-current
   ```

3. **Launch claude-sandbox**:
   ```bash
   REPO_URL="[discovered-url]" claude-sandbox local "[task from $ARGUMENTS]"
   ```

4. **Output confirmation**:
   ```
   Launching sandbox for: [repo-name]
   Task: [task description]
   Branch context: [current-branch]
   ```

## Error Handling

- **Not a git repo**: "Error: Must run from within a git repository"
- **No origin remote**: "Error: Repository has no origin remote. Add one with: git remote add origin <url>"
- **Missing env vars**: "Error: Missing required environment variables: [list]. See: claude-sandbox --help"
- **claude-sandbox not in PATH**: "Error: claude-sandbox not found. Install it first."

## Rules

- Do NOT ask for confirmation - just launch
- Do NOT use direnv variables for REPO_URL - always discover from git
- The task description is everything in $ARGUMENTS
- Pass the task exactly as provided to claude-sandbox

## Examples

**Success case**:
```
$ /sandbox "fix the authentication bug"

Launching sandbox for: my-app
Task: fix the authentication bug
Branch context: main
[claude-sandbox output follows...]
```

**Error case**:
```
$ /sandbox "add feature X"
Error: Not in a git repository
```
