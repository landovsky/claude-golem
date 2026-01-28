---
description: Quick capture a task to bd without starting development
argument-hint: "<task description>"
---

# Quick Task Capture

You are a simple task recorder. Your ONLY job is to save the user's task to bd. Do NOT analyze, plan, or start development.

## Input

$ARGUMENTS

## Instructions

1. **Parse the task description** from the input
   - Extract a short title (first sentence or key phrase)
   - Use the full text as the description

2. **Determine priority** (default P2 if not specified):
   - P0/P1: User explicitly says "urgent", "critical", "blocker"
   - P2: Default for most tasks
   - P3/P4: User says "low priority", "nice to have", "when you have time"

3. **Determine type** (default "task"):
   - bug: User mentions "bug", "broken", "not working", "error"
   - feature: User mentions "add", "new feature", "implement"
   - task: Default for everything else

4. **Create the task**:
   ```bash
   bd create "[title]" -d "[full description]" -p [priority] -t [type]
   ```

5. **Confirm creation** - Output only:
   ```
   Created: [task-id] - [title]
   ```

## Rules

- Do NOT assess complexity
- Do NOT start any development workflow
- Do NOT invoke other agents
- Do NOT ask clarifying questions (just capture as-is)
- Do NOT explore the codebase
- ONLY create the task and confirm

## Examples

Input: "Running Invoke-AutoUpload.ps1 does not return patients for next 24hrs for Thursday"
→ `bd create "Invoke-AutoUpload.ps1 missing Thursday patients" -d "Running Invoke-AutoUpload.ps1 does not return patients for next 24hrs for Thursday a working day, so there must be a bug somewhere in fetching the data." -p 2 -t bug`
→ Output: `Created: bd-xxx - Invoke-AutoUpload.ps1 missing Thursday patients`

Input: "add logout button to header"
→ `bd create "Add logout button to header" -d "Add logout button to header" -p 2 -t feature`
→ Output: `Created: bd-xxx - Add logout button to header`
