# Lessons Learned

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

## 2026-01-31 - .claude-gvl - Severity tracking for reviewer metrics

### What worked well
- Using bd comments for append-only metrics storage is elegant for concurrent safety. The pattern in `agents/reviewer.md` Phase 5.5 (lines 116-304) shows how to use a dedicated task (`.claude-metrics`) as a persistent data store rather than a work item.
- HEREDOC pattern with unquoted delimiter (`<<EOF` not `<<'EOF'`) correctly allows `$TIMESTAMP` variable substitution while avoiding shell escaping issues with JSON quotes. See command template at `agents/reviewer.md` lines 199-227.
- Separating schema documentation (field definitions at lines 186-193) from examples (zero-issue at 233-248, multi-issue at 250-297) makes the spec clear and testable.
- Including explicit zero-issue example prevents ambiguity about empty state representation.

### What to avoid
- When adding shell commands that require variable substitution inside quoted strings, verify whether HEREDOC should use quoted (`<<'EOF'`) or unquoted (`<<EOF`) delimiter. Quoted prevents all expansion (safe for literal content), unquoted allows `$VAR` expansion (needed for dynamic values like timestamps).

### Process improvements
- For any feature that introduces a new persistent bd task (like `.claude-metrics`), the plan should include the exact `bd create` command with flags. The plan at lines 62-70 did this correctly, making setup unambiguous.
- When documenting JSON schemas in markdown, include both the schema definition AND a validation example that consuming tools can use. The reviewer.md examples can be extracted and piped to `python3 -m json.tool` for automated validation.
