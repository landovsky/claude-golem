# Usage Metrics Collection Test Utility

Automated test script to validate that SubagentStart/SubagentStop hooks are properly collecting token usage, costs, and duration metrics.

## What It Does

The test utility performs a complete end-to-end validation:

1. **Pre-flight Checks** - Verifies infrastructure is ready
   - Hook scripts exist and are executable
   - Settings.json has correct hook configuration
   - Required commands available (jq, bd, claude-sandbox)
   - Hooks work when invoked manually

2. **Test Task Creation** - Creates a BD task designed to trigger full workflow
   - Simple utility function implementation
   - Will invoke planner → implementer → reviewer stages

3. **Workflow Execution** - Runs the development workflow via claude-sandbox
   - Executes: `claude-sandbox local '/develop task-id'`
   - Triggers all workflow stages to generate metrics

4. **Acceptance Criteria Validation** - Verifies metrics were captured correctly
   - ✓ Metrics file created (`.claude/workflow-metrics.jsonl`)
   - ✓ Stage start/end events captured (>= 3 pairs)
   - ✓ Token data present (input/output/cache tokens)
   - ✓ Cost calculated (USD amounts > 0)
   - ✓ Model information captured
   - ✓ Duration measured (seconds > 0)
   - ✓ BD comments posted on subtasks
   - ✓ Expected stages present (planner, implementer, reviewer)

## Usage

```bash
# Run the test
~/.claude/test-usage-collection.sh
```

The script will:
- Stop immediately if pre-flight checks fail
- Create a test task and run the full workflow
- Display pass/fail for each criterion
- Show a summary of metrics collected
- Exit with code 0 on success, 1 on failure

## Output

### Success Output
```
=========================================
Usage Metrics Collection Test Utility
=========================================

Phase 1: Pre-flight Checks
-------------------------------------------
✓ Hook scripts exist and are executable
✓ Hooks configured in settings.json with correct matcher
✓ Required commands available (jq, bd, claude-sandbox)
✓ Manual hook test successful

Pre-flight Summary: 4 passed, 0 failed

✓ All pre-flight checks passed!

Phase 2: Creating Test Task
-------------------------------------------
✓ Created test task: .claude-abc

Phase 3: Running Development Workflow
-------------------------------------------
✓ Workflow completed successfully

Phase 4: Verifying Acceptance Criteria
-------------------------------------------
✓ Metrics file exists: .claude/workflow-metrics.jsonl
✓ Stage events captured: 3 starts, 3 ends
✓ Token data captured in 3 stage_end events
✓ Cost calculated: 3 events, total: $0.0523
✓ Model captured in 3 events
✓ Duration captured in 3 events
✓ BD comments with metrics found on 3 subtasks
✓ Expected workflow stages present

=========================================
TEST RESULTS
=========================================

Acceptance Criteria: 8/8 passed

✓ ALL TESTS PASSED

Usage metrics collection is working correctly!
```

### Failure Output

If any check fails, the script will:
- Display ✗ for failed checks
- Show detailed error information
- Provide debug file locations
- Exit with non-zero status

## Files Created

- **Test task**: Created in BD with format `.claude-xxx`
- **Metrics file**: `~/.claude/workflow-metrics.jsonl` (backed up if exists)
- **Workflow output**: Temporary file with claude-sandbox output
- **Backup**: Previous metrics saved to `workflow-metrics.jsonl.backup.<timestamp>`

## Cleanup

After a successful test run:

```bash
# View the metrics collected
jq 'select(.event=="stage_end")' ~/.claude/workflow-metrics.jsonl

# Close the test task
bd close .claude-xxx

# Optional: Remove test utilities if no longer needed
rm -rf utils/greeting.js  # The test file created
```

## Troubleshooting

### Pre-flight check failures

**"Hook scripts missing or not executable"**
- Check: `ls -la ~/.claude/hooks/metrics-*.sh`
- Fix: Ensure scripts exist and run `chmod +x ~/.claude/hooks/metrics-*.sh`

**"Hooks not configured in settings.json"**
- Check: `jq '.hooks' ~/.claude/settings.json`
- Fix: Add SubagentStart/SubagentStop hooks to settings.json

**"Missing commands"**
- Install missing tools:
  - `jq`: `brew install jq`
  - `bd`: Install beads CLI
  - `claude-sandbox`: Part of Claude Code installation

### Acceptance criteria failures

**"Token data missing"**
- Check that agent transcripts are being written
- Verify transcript path in hook input

**"BD comments missing"**
- Check that TASK environment variable matches beads ID format
- Verify bd CLI is accessible from hook script

**"Cost calculation missing"**
- Verify transcript contains usage.input_tokens and usage.output_tokens
- Check model name extraction logic

## Advanced Usage

### Run with custom metrics file location

Edit the script to change `JSONL_FILE` path in both hook scripts before running.

### Verbose output

The script already shows detailed output. For debugging hook execution:

```bash
# Test hooks manually with verbose output
set -x
echo '{"agent_id":"test","agent_type":"planner","session_id":"test"}' | \
  TASK="Manual test" ~/.claude/hooks/metrics-start.sh
set +x
```

### Query metrics after test

```bash
# Total cost by stage
jq -s 'group_by(.stage) | map({stage: .[0].stage, total_cost: (map(.cost_usd // 0) | add)})' \
  ~/.claude/workflow-metrics.jsonl

# Average duration per stage
jq -s 'group_by(.stage) | map({stage: .[0].stage, avg_duration: (map(.duration_seconds) | add / length)})' \
  ~/.claude/workflow-metrics.jsonl

# Most expensive tasks
jq 'select(.event=="stage_end")' ~/.claude/workflow-metrics.jsonl | \
  jq -s 'sort_by(-.cost_usd) | .[0:10]'
```

## Exit Codes

- `0` - All tests passed
- `1` - Pre-flight checks failed OR acceptance criteria not met

## Requirements

- Claude Code CLI installed
- Beads (`bd`) CLI installed
- `jq` command-line JSON processor
- `claude-sandbox` (part of Claude Code)
- Git repository initialized
- Hook scripts at `~/.claude/hooks/metrics-{start,end}.sh`
- Settings configured in `~/.claude/settings.json`
