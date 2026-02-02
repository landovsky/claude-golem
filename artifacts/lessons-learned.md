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

## 2026-02-01 - .claude-de5 - Parameterize Docker image for forks

### What worked well
- Using `github.repository_owner` in GitHub Actions is the right approach - no custom parsing needed, works for all forks automatically.
- Following the existing `auto_detect_repo` pattern in the codebase made the implementation consistent and predictable.
- Documenting the fallback chain (explicit override > auto-detect > hardcoded default) makes debugging easier.

### What to avoid
- **Sed pattern pass-through on non-match**: When using sed to extract values from URLs, be aware that non-matching patterns pass through unchanged. The initial implementation would create invalid Docker image names like `git@gitlab.com:user/repo.git/claude-sandbox:latest` for non-GitHub remotes.
- **Fix**: Always validate extracted values match expected format before using them. In this case, checking that extracted owner matches `^[a-zA-Z0-9_-]+$` catches invalid pass-through.

### Process improvements
- **Planner checklist addition**: When parsing URLs with regex, list what happens when patterns don't match. Include non-matching cases in the testing approach.
- **Reviewer testing**: For URL/string parsing functions, always test with inputs that are similar but not exact matches to the expected pattern (e.g., GitLab URL when expecting GitHub).

## 2026-02-01 - .claude-53k - Service detection in entrypoint.sh

### What worked well
- **Plan with exact code snippets**: The planner provided complete bash code for detection logic, which the implementer could directly adopt. This eliminated ambiguity about grep patterns, variable names, and section structure.
- **Pattern references to line numbers**: Referencing existing code (lines 137-163, line 147 specifically for grep pattern) ensured the new code matched established conventions exactly.
- **Explicit consumer contracts**: Plan specified exact variable names (NEEDS_POSTGRES, NEEDS_MYSQL, etc.) that Phase 2/3 will use, preventing naming mismatches across phases.
- **Acceptable false positives documented**: Plan explicitly stated that detecting commented-out gems is acceptable (over-provision vs. fail). This preempts reviewer nitpicks about edge cases.

### What to avoid
- **Branch naming with dots**: Git does not allow branch names starting with a dot. The plan specified `feature/.claude-53k-service-detection` but git rejected it. Use `feature/claude-53k-service-detection` pattern instead.

### Process improvements
- **Planner checklist addition**: When specifying branch names, avoid leading dots in any path segment. Git has restrictions on special characters in branch names.
- **Multi-phase features benefit from explicit interface contracts**: For features spanning multiple tasks (Phase 1 detection, Phase 2 docker-compose, Phase 3 k8s), define the exact variable/flag names in Phase 1 plan so later phases can reference them without ambiguity.

## 2026-02-01 - .claude-4nq - Docker Compose dynamic service profiles

### What worked well
- **Timing paradox identified early**: The plan correctly identified that entrypoint.sh detection runs INSIDE the container AFTER Docker Compose starts, but profiles must be decided BEFORE. Creating a pre-launch detection script (`bin/detect-services.sh`) solved this cleanly.
- **Two-detection-point architecture**: Keeping both pre-launch detection (for profiles) and in-container detection (for logging/validation) provides redundancy. Good architectural decision.
- **Fallback chain design**: Empty detection -> all services, missing script -> all services, git archive fails -> all services. The "fail open" approach ensures existing setups never break.
- **Profile naming as interface contract**: Plan specified exact profile names ("with-postgres", "with-redis", "claude") as the contract between docker-compose.yml and the launcher. Clean separation of concerns.
- **Implementer judgment on documentation location**: Plan incorrectly specified `/Users/tomas/.claude/README.md` but implementer correctly placed docs in `/Users/tomas/.claude/claude-sandbox/README.md` since it's a sandbox-specific feature.

### What to avoid
- **Trailing whitespace in shell pipelines**: The deduplication `echo "$profiles" | tr ' ' '\n' | sort -u | tr '\n' ' '` leaves trailing whitespace. While harmless in this case (word splitting handles it), it could cause issues in other contexts. Consider `| xargs` or `| sed 's/ $//'` to clean output.

### Process improvements
- **Planner: verify file path correctness for documentation updates**: The plan listed updating `/Users/tomas/.claude/README.md` when the correct location was `claude-sandbox/README.md`. File paths in "Documentation to update" should be verified against actual file structure.
- **Multi-component features need timing analysis**: When a feature involves multiple components (pre-launch script, docker-compose, entrypoint), the plan should explicitly diagram the timing relationship (what runs when, what data is available at each point).

## 2026-02-01 - .claude-ogp - K8s dynamic sidecar generation (Phase 3)

### What worked well
- **Bash heredoc YAML generation**: The `generate_k8s_job_yaml()` function uses bash heredocs with conditional blocks to generate YAML dynamically. This approach maintains readability while enabling conditional sidecar inclusion. See `/Users/tomas/.claude/claude-sandbox/bin/claude-sandbox` lines 319-458.
- **Consistent interface reuse**: Phase 3 reuses the exact same `detect-services.sh` script and profile names ("with-postgres", "with-redis") established in Phase 2. No new contracts needed - just consuming existing ones.
- **Comprehensive testing approach in TESTING.md**: The documentation includes specific kubectl commands to verify container counts and env vars for each scenario, making validation repeatable.
- **Reference template preservation**: Keeping `job-template.yaml` as "REFERENCE ONLY" with clear note (lines 1-9) helps future maintainers understand the full structure without wading through heredoc conditionals.

### What to avoid
- **YAML injection via envsubst**: When using `envsubst` for user-provided values (like TASK), special characters (quotes, newlines) can break YAML syntax. The pattern `value: "${TASK}"` is vulnerable. This existed in the original template but the dynamic generation replicates it. Future work should escape values with a helper function or use base64 encoding.
- **Pre-existing technical debt replication**: The implementer correctly replicated existing patterns, but this also replicated existing vulnerabilities. Reviewers should flag pre-existing issues even when not fixing them, to track technical debt.

### Process improvements
- **Security checklist for template generation**: When generating configuration files (YAML, JSON) with user input, the plan should include a "string escaping" consideration. Questions to ask: What characters could break the format? Are values properly quoted/escaped?
- **Multi-phase completion tracking**: TESTING.md still had a "To Do" section referencing Phase 1/2 items. When completing later phases, clean up earlier phase tracking items to maintain documentation accuracy.

## 2026-02-02 - .claude-l86 - PostGIS Support for K8s Sidecars

### What worked well
- **Universal upgrade strategy**: Using PostGIS universally instead of PostgreSQL-or-PostGIS conditional logic eliminated complexity. Since PostGIS is fully backward compatible with PostgreSQL, this "upgrade all" approach is simpler and equally safe.
- **Pre-verified approach via Docker Compose**: Docker Compose already used PostGIS successfully, so the K8s changes were just "make it match". This reduced risk and provided a working reference.
- **Minimal scope, clear boundaries**: The spec explicitly stated "out of scope" items (readiness checks, other databases), preventing scope creep. Four string replacements was the entire implementation.
- **Documentation already complete**: The analyst noted README already documented PostGIS support, so no doc updates were needed. Good spec research prevented unnecessary work.

### What to avoid
- **Test templates can get stale**: `k8s/job-template-test.yaml` has commented-out examples showing old `postgres://` and `postgres:16-alpine`. While not functional code, stale examples in test templates can confuse future developers who uncomment them.
- **Example files in docs may intentionally differ**: Not all `postgres://` references need updating. Documentation examples showing user-provided external database URLs (e.g., `.env.claude-sandbox.example`) are intentionally generic since users may connect to non-PostGIS databases.

### Process improvements
- **Analyst checklist addition**: When changing default database/service images, identify: (1) functional code to update, (2) reference templates to update, (3) test templates to update, (4) documentation examples that should NOT be updated (because they show user-configurable values).
- **Backward compatibility simplifies planning**: When an upgrade is fully backward compatible (like PostgreSQL to PostGIS), the plan can be simpler - no feature flags, no detection logic, no conditional paths. Identify compatibility level early in analysis.
