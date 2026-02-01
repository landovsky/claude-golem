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

## 2026-02-01 - .claude-csa - Docker CI/CD workflow

### What worked well
- Plan correctly identified the claude-config directory problem and provided a clear solution (create minimal config in CI).
- Clear trigger strategy using regex pattern `v[0-9]+.[0-9]+.[0-9]+` covers semver tags without catching pre-releases.
- Using standard GitHub Actions (checkout@v4, docker/login-action@v3, docker/build-push-action@v5) ensures maintainability.

### What to avoid
- **Multi-arch builds require full stack verification**: Enabling `platforms: linux/amd64,linux/arm64` without checking if Dockerfile dependencies support arm64 will cause silent failures. In this case, `claude-sandbox/Dockerfile` lines 72-77 hardcode amd64 URLs for SOPS and age binaries.
- Planner listed multi-arch as an option but didn't flag the Dockerfile architecture dependency as a blocker.

### Process improvements
- **Analyst checklist addition**: When specifying CI/CD for Docker images, verify all Dockerfile RUN commands that download binaries support the target architectures.
- **Security baseline for GitHub Actions**: Always include explicit `permissions:` block with minimal required permissions. Default permissions are too broad.
- When adding new workflow files, run a quick syntax check before committing (e.g., use actionlint or YAML validator).
