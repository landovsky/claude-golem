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

## 2026-02-01 - .claude-yad - Multi-Ruby version support via image tagging

### What worked well
- **Detailed plan with pseudocode**: The planner's plan included pseudocode for `auto_detect_ruby_version()` function, making the implementation straightforward. The implementer followed it nearly line-by-line.
- **Pattern references in plan**: Pointing to specific files/lines (e.g., `bin/claude-sandbox` lines 241-290, `auto_detect_repo` lines 54-80) helped maintain consistency.
- **grep/awk for YAML**: Using `grep -E '^\s*"[0-9]+\.[0-9]+":\s*"[0-9]+\.[0-9]+\.[0-9]+"'` to parse the simple YAML structure avoided external dependencies (yq/python) and kept the script portable.
- **Detection timing reasoning**: The plan explicitly noted that `.ruby-version` detection must happen in launcher (before container start), not in entrypoint, because the file is in the repo which doesn't exist until clone. This prevented a subtle bug.

### What to avoid
- **Relying on file order for "latest"**: The build loop picks the last version in `ruby-versions.yaml` as the one to tag as `:latest`. This is implicit behavior that could surprise someone adding a new version in the middle of the file. Future consideration: use the `default` field explicitly for this purpose.
- **git archive limitation**: GitHub.com does not support `git archive --remote` for HTTPS URLs, so auto-detection only works for local repos or self-hosted Git servers that enable this. This was documented but is a real limitation for many workflows.

### Process improvements
- For features involving version/tag selection, the plan should specify explicitly which version gets the "default" or "latest" designation and how that's determined (highest version? explicit config? last in file?).
- When a feature has known platform limitations (like git archive not working on GitHub.com), the plan should call this out in the "Watch out for" section so the implementer can design around it or document it prominently.
