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

## 2026-02-03 - .claude-l0a - Usage Metrics Collection (Phase 1)

### What worked well
- **jq for JSON generation prevents injection**: Using `jq -nc --arg field "$value"` pattern (see `/Users/tomas/.claude/hooks/metrics-start.sh` lines 32-47) safely escapes all user input. This is the correct pattern for any hook that generates JSON from environment variables or user input.
- **Exit 0 always pattern**: `set +e` at script top combined with `|| true` on critical operations (file writes, bd commands) ensures hooks never break the workflow. This is essential for any Claude Code hook script.
- **Portable date handling with fallback chain**: The pattern in `/Users/tomas/.claude/hooks/metrics-end.sh` lines 43-55 handles gdate (homebrew), GNU date (Linux), and BSD date (macOS) automatically. Copy this pattern for any duration/timestamp calculations in hook scripts.
- **Test data as verification**: The committed `workflow-metrics.jsonl` with test scenarios (truncation, blocked status, fallback values) provides immediate evidence that edge cases were tested.

### What to avoid
- **Hardcoding absolute paths in hook scripts**: Both hook scripts use `/Users/tomas/.claude/workflow-metrics.jsonl`. For personal use this works, but for distributable hooks use `$CLAUDE_PROJECT_DIR/.claude/workflow-metrics.jsonl` to maintain portability.
- **Assuming settings.json can be committed**: Claude's settings.json is user-specific and typically in .gitignore. Document manual setup steps rather than expecting hook configurations to auto-apply.

### Process improvements
- **Spec should clarify user-specific vs project files**: The spec listed "Update settings.json with hook configuration" as a requirement, but settings.json is user-specific (in .gitignore). The implementer correctly handled this by documenting the manual setup, but the spec could have been clearer by noting "(user must add manually - file not committed)".
- **Include conditional logic for edge cases in spec**: The implementer added a smart check for task ID format before posting bd comments (only posts if task contains `.`). This prevents errors but was not in the spec. Analyst should consider defensive conditions for external service calls.

## 2026-02-03 - .claude-6t5 - Usage Metrics Phase 2 (OTLP Token Data)

### What worked well
- **grep + jq pipeline for JSONL parsing**: The pattern `grep '"type":"assistant"' "$file" | jq -s '[.[] | .field] | add // 0'` efficiently filters and aggregates data from large transcript files. grep pre-filters for speed, jq handles JSON safely. See `/Users/tomas/.claude/hooks/metrics-end.sh` lines 79-89.
- **Case statement with glob patterns for model pricing**: Using `*opus-4.5*|*opus-4-5*` style patterns handles model name variations (dashes vs dots) without complex regex. See lines 98-112 in metrics-end.sh.
- **awk for floating-point cost calculation**: Bash cannot do decimals. The `awk -v var="$val" 'BEGIN { printf "%.4f", calculation }'` pattern is portable and precise. See lines 115-125.
- **Zero-to-null conversion preserves schema**: The jq expression `($input_tokens | if . == 0 then null else . end)` maintains backward compatibility - existing queries expecting null for "no data" still work.
- **Planner's detailed implementation approach**: The plan included exact line numbers for insertion points, complete code blocks, and step-by-step guidance. The implementer followed it exactly with zero deviations.

### What to avoid
- **Empty grep output piped to jq returns empty string, not null**: When parsing `grep '"type":"assistant"' "$file" | tail -1 | jq -r '.field // "null"'`, if grep returns nothing, jq gets empty input and outputs empty string, not "null". This only matters for rare edge cases (transcript with no assistant messages) but could cause unexpected behavior if comparing to "null" string.
- **Fix**: Add a fallback: `result=$(... | jq -r '...' 2>/dev/null); [[ -z "$result" ]] && result="null"`

### Process improvements
- **Multi-phase features benefit from incremental testing**: Phase 1 established the JSONL schema with null values. Phase 2 only changed the values, not the schema. This made validation simple: just verify the schema matches. Plan multi-phase features with "schema first, data later" when possible.
- **Transcript format is undocumented API**: The agent_transcript_path JSONL format is not officially documented by Anthropic. The spec correctly identified this risk and the implementation uses defensive parsing. Future features relying on transcript parsing should include explicit versioning or format detection.
- **Cost precision requirements should be explicit**: The spec noted "4 decimal places" for cost. This drove the awk `printf "%.4f"` decision. Precision requirements should always be in the spec to avoid ambiguity.

## 2026-02-04 - .claude-790 - Metrics Collection Workflow Validation Test

### What worked well
- **Defensive bd comment guard**: The check `[[ "$task_raw" =~ \. ]]` in `/Users/tomas/.claude/.claude/hooks/metrics-end.sh` line 171 correctly prevents posting garbage comments when `$TASK` is invalid. Without this, the hook would try to post to "unknown-task" and fail noisily.
- **Metrics infrastructure works independently of bd comments**: Even when bd comments fail (due to invalid task ID), the JSONL file still receives correct stage_start/stage_end events with token data, cost, duration, and stage names. The system degrades gracefully.
- **Analyst risk identification**: The analyst spec explicitly flagged "$TASK environment variable may not be set correctly by master" as an open risk. This proved accurate and helped the reviewer understand the root cause immediately.
- **Verification task design**: Using a trivial pre-existing implementation (greeting utility) to exercise the full workflow (analyst -> planner -> implementer -> reviewer) was the right approach. It isolated "does the infrastructure work" from "did we build something new."

### What to avoid
- **Assuming environment variables are passed automatically**: The hooks depend on `$TASK` being set by master before spawning subagents. The hooks have no way to discover their own task ID - they rely entirely on this env var. If master doesn't set it, the hook cannot self-recover.
- **Testing hooks in isolation vs integration**: The hooks were tested in isolation (Phase 1, Phase 2) and worked. But the full workflow test revealed that master's env var passing was missing. Unit tests passed, integration test partially failed. Always test hooks end-to-end with actual subagent spawning.

### Process improvements
- **Master checklist addition**: When master spawns a subagent, it must pass `TASK=[subtask-id]` in the environment. Add this to master's spawn procedure documentation.
- **Hook debugging approach**: When bd comments don't appear, check `workflow-metrics.jsonl` for the task value first. If it shows "unknown-task", the issue is upstream (master not setting env var), not in the hooks.
- **Staged rollout for workflow features**: Test infrastructure features in isolation first (hooks alone), then with mocked env vars, then with actual workflow execution. This test revealed a gap in the middle stage - env var passing wasn't verified before full workflow test.

## 2026-02-04 - .claude-790 (Run 2) - Metrics Validation Second Run

### What worked well
- **Re-run of existing implementation is fast**: Run 2 analyst completed in 38s vs run 1's 191s (80% faster). When stages verify existing work rather than creating new work, the workflow completes much faster. Use verification runs to isolate infrastructure testing from feature work.
- **Metrics comparison across runs**: Having run 1 and run 2 in the same JSONL file with the same session_id made A/B comparison straightforward. The session_id continuity across runs enables workflow analysis.
- **bd comments as stage data transport works**: Analyst and planner specs were successfully posted and retrieved via `bd comments` - the primary data transport mechanism is functioning as designed.
- **Cache utilization visible in metrics**: Run 2 showed higher cache_read ratios relative to input tokens, indicating the system benefits from repeated operations. This is valuable data for cost optimization.

### What to avoid
- **Confusing wall-clock time with processing time**: Run 2 implementer showed 2474s duration but only $0.19 cost. This was wall-clock time including human pauses, not actual processing. When analyzing metrics, cross-reference duration with cost - if cost is low but duration is high, there was idle time.
- **Over-testing trivial implementations**: The greeting utility tests use manual console.log assertions. For a validation task this is fine, but creates technical debt if copied to real features. The plan should note when "quick and dirty" testing is acceptable vs when proper test framework is required.

### Process improvements
- **Metrics schema is stable and working**: After two full workflow runs, the JSONL schema (stage_start/stage_end with tokens, cost, duration, model, session_id) has proven reliable. This schema can be documented as the standard for workflow instrumentation.
- **Known $TASK gap needs dedicated fix**: Two runs have confirmed the $TASK environment variable gap. Rather than continuing to document it as "known issue", a dedicated task should address master's subagent spawning to include `TASK=$subtask_id`. This is blocking bd comment posting from hooks.
- **Verification runs are valuable QA tool**: Running the same workflow twice with existing implementation catches infrastructure issues without conflating them with implementation bugs. Consider making "dry run" a standard QA step for workflow changes.

## 2026-02-04 - .claude-791 - Timestamp Formatter Utility (Validation Task)

### What worked well
- **Detailed plan with exact code blocks**: The planner provided complete implementation code in the plan, allowing the implementer to follow it precisely. Zero deviations from plan indicates the level of detail was appropriate.
- **Regex for time-sensitive tests**: The plan explicitly warned about test timing sensitivity and prescribed using `/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/` regex validation instead of exact string matching for current-time cases. This avoids flaky tests. See `/workspace/utils/time-formatter.test.js` line 15.
- **Pattern reference to existing code**: Pointing to `greeting.js` and `greeting.test.js` as the canonical patterns made code review trivial - implementation matches patterns exactly.
- **Combined invalid input check**: The single condition `!date || !(date instanceof Date) || isNaN(date.getTime())` elegantly handles all edge cases (null, undefined, no argument, invalid Date object) in one line. See `/workspace/utils/time-formatter.js` line 8.

### What to avoid
- **Console.log tests lack exit codes**: The test pattern inherited from `greeting.test.js` does not set process exit code on failure. If integrated into CI, failures would not be detected. For validation tasks this is acceptable per lessons-learned line 189, but real features need proper test framework.
- **No test summary output**: Neither test file outputs a summary (e.g., "6/6 passed"). For manual verification this is fine, but automated test runners benefit from clear pass/fail summaries.

### Process improvements
- **Validation tasks can be reviewer-light**: For trivial implementations that exactly follow a detailed plan with exact code blocks, the reviewer phase adds minimal value beyond "tests pass, code matches plan." Consider fast-tracking such tasks.
- **Planner code blocks reduce review time**: When the plan includes complete, correct implementation code, the implementer becomes a transcriber and the reviewer becomes a verifier. This shifts quality assurance left to the planner phase.
