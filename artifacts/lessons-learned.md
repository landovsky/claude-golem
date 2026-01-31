# Lessons Learned

## 2026-01-31 - .claude-47 - Authentication error handling in claude-sandbox

### What worked well
- Single jq filter with if-then-elif-else for dual event handling (text_delta and errors) is clean and performant
- Testing with invalid API key (`ANTHROPIC_API_KEY="invalid"`) immediately revealed the actual error event structure
- Claude CLI error events have consistent structure across different invalid key formats
- Fallback chains in jq (`.message.content[0].text // .result // .error`) handle multiple error event formats robustly
- Color-coded error prefix `\u001b[31m[claude error]\u001b[0m` makes errors visually distinct in logs

### What to avoid
- Don't assume error event structure matches text_delta structure - they use completely different event types
- Don't assume jq's `stderr` function works the same across all versions and environments - test early or use simpler output approaches
- Testing with actual invalid credentials is required to see true error format - specs and hypotheses aren't enough

### Discovered error event structure
Claude CLI `--output-format stream-json` emits these events on authentication failure:
- `{"type":"assistant", "message":{"content":[{"text":"Invalid API key · Fix external API key"}]}, "error":"authentication_failed"}`
- `{"type":"result", "is_error":true, "result":"Invalid API key · Fix external API key"}`

Both events contain the user-facing error message, so the filter handles both to catch all error scenarios.

### Pattern for future
- When using `--output-format stream-json`, always handle multiple event types (not just the "happy path" events)
- For error visibility, color coding and clear prefixes are more important than stdout/stderr separation
- Test filters with real CLI output, not just synthetic JSON - the actual event structure may surprise you
- Use jq from file (`jq -f filter.jq`) for complex multi-line filters to avoid shell quoting issues

## 2026-01-28 - .claude-9nr - Fix inter-stage data passing

### What worked well
- The bd comments approach in `agents/analyst.md`, `agents/planner.md`, and `agents/reviewer.md` provides clear primary/fallback output patterns. The "primary: bd comment, secondary: file" framing is easy for agents to follow.
- `artifacts/workflow-design/WORKFLOW.md` Stage Outputs section (lines 142-179) gives a clear visual example of the data flow with task IDs, making the pattern concrete.
- Master's Output Validation table (`agents/master.md` lines 156-161) makes expected outputs per agent unambiguous.

### What to avoid
- When changing an agent's primary output mechanism to require a new tool (e.g., Bash for `bd comments add`), always verify the agent's toolset declaration includes that tool. The analyst was given bd comment instructions but lacked Bash in its toolset -- this would have silently failed at runtime.
- Checklist for toolset changes: if an agent instruction says "run X command", verify X's tool is in the frontmatter `tools:` line.

### Process improvements
- Planner should include a "toolset verification" step: for each agent being modified, confirm the frontmatter toolset supports all commands referenced in the instructions. The plan correctly noted "add Bash to planner" but missed the same requirement for analyst.
- When spec recommends one approach and planner chooses another, the plan should explicitly state why it diverged. The plan here silently chose bd comments over master-as-relay without documenting the tradeoff reasoning.
