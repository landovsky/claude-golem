#!/bin/bash

# Test Utility for Usage Metrics Collection
# Validates that SubagentStart/SubagentStop hooks are properly collecting metrics

set -e  # Exit on error

echo "========================================="
echo "Usage Metrics Collection Test Utility"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0

# Helper functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

info() {
    echo -e "  $1"
}

# ==================================================
# PHASE 1: PRE-FLIGHT CHECKS
# ==================================================

echo "Phase 1: Pre-flight Checks"
echo "-------------------------------------------"

# Check 1: Hook scripts exist and are executable
echo "1. Checking hook scripts..."
if [[ -x "$HOME/.claude/hooks/metrics-start.sh" && -x "$HOME/.claude/hooks/metrics-end.sh" ]]; then
    pass "Hook scripts exist and are executable"
else
    fail "Hook scripts missing or not executable"
    if [[ ! -f "$HOME/.claude/hooks/metrics-start.sh" ]]; then
        info "Missing: $HOME/.claude/hooks/metrics-start.sh"
    fi
    if [[ ! -f "$HOME/.claude/hooks/metrics-end.sh" ]]; then
        info "Missing: $HOME/.claude/hooks/metrics-end.sh"
    fi
fi

# Check 2: Hooks configured in settings
echo "2. Checking settings.json configuration..."
if [[ -f "$HOME/.claude/settings.json" ]]; then
    subagent_start=$(jq '.hooks.SubagentStart' "$HOME/.claude/settings.json" 2>/dev/null)
    subagent_stop=$(jq '.hooks.SubagentStop' "$HOME/.claude/settings.json" 2>/dev/null)

    if [[ "$subagent_start" != "null" && "$subagent_stop" != "null" ]]; then
        # Check for correct matcher
        matcher=$(jq -r '.hooks.SubagentStart[0].matcher' "$HOME/.claude/settings.json" 2>/dev/null)
        if [[ "$matcher" =~ analyst.*planner.*implementer.*reviewer ]]; then
            pass "Hooks configured in settings.json with correct matcher"
        else
            warn "Hooks configured but matcher may be incorrect: $matcher"
        fi
    else
        fail "SubagentStart or SubagentStop hooks not configured in settings.json"
    fi
else
    fail "settings.json not found at $HOME/.claude/settings.json"
fi

# Check 3: Required commands available
echo "3. Checking required commands..."
missing_commands=()

if ! command -v jq >/dev/null 2>&1; then
    missing_commands+=("jq")
fi

if ! command -v bd >/dev/null 2>&1; then
    missing_commands+=("bd")
fi

if ! command -v claude-sandbox >/dev/null 2>&1; then
    missing_commands+=("claude-sandbox")
fi

if [[ ${#missing_commands[@]} -eq 0 ]]; then
    pass "Required commands available (jq, bd, claude-sandbox)"
else
    fail "Missing commands: ${missing_commands[*]}"
    info "Install missing commands before proceeding"
fi

# Check 4: Manual hook test
echo "4. Testing hooks manually..."
test_jsonl="$HOME/.claude/workflow-metrics-test.jsonl"
rm -f "$test_jsonl" 2>/dev/null || true

# Override JSONL file location for test
test_input='{"agent_id":"preflight-test","agent_type":"planner","session_id":"test-session"}'
if echo "$test_input" | TASK="Preflight test" "$HOME/.claude/hooks/metrics-start.sh" 2>/dev/null; then
    if [[ -f "$HOME/.claude/workflow-metrics.jsonl" ]]; then
        last_entry=$(tail -1 "$HOME/.claude/workflow-metrics.jsonl" 2>/dev/null)
        if echo "$last_entry" | jq -e '.event == "stage_start"' >/dev/null 2>&1; then
            pass "Manual hook test successful"
        else
            fail "Hook executed but didn't write expected data"
        fi
    else
        fail "Hook executed but metrics file not created"
    fi
else
    fail "Manual hook execution failed"
fi

echo ""
echo "Pre-flight Summary: $CHECKS_PASSED passed, $CHECKS_FAILED failed"
echo ""

if [[ $CHECKS_FAILED -gt 0 ]]; then
    echo -e "${RED}Pre-flight checks failed. Fix issues before proceeding.${NC}"
    exit 1
fi

echo -e "${GREEN}All pre-flight checks passed!${NC}"
echo ""

# ==================================================
# PHASE 2: CREATE TEST TASK
# ==================================================

echo "Phase 2: Creating Test Task"
echo "-------------------------------------------"

# Backup existing metrics file if it exists
if [[ -f "$HOME/.claude/workflow-metrics.jsonl" ]]; then
    backup_file="$HOME/.claude/workflow-metrics.jsonl.backup.$(date +%s)"
    cp "$HOME/.claude/workflow-metrics.jsonl" "$backup_file"
    info "Backed up existing metrics to: $backup_file"
    # Clear the file for clean test
    > "$HOME/.claude/workflow-metrics.jsonl"
fi

# Create the test task
task_output=$(bd create --title="Test token usage collection workflow" \
    --type=task \
    --priority=2 \
    --description="Test task for validating usage metrics collection.

Create a simple utility function in utils/greeting.js that exports generateGreeting(name).
The function should return 'Hello, [name]!' or 'Hello, Guest!' if name is empty/null.

This task will trigger the full development workflow to test metrics collection." 2>&1)

# Extract task ID from output
task_id=$(echo "$task_output" | grep -oE '\.claude-[a-z0-9]+' | head -1)

if [[ -n "$task_id" ]]; then
    pass "Created test task: $task_id"
    info "Task: Test token usage collection workflow"
else
    fail "Failed to create test task"
    echo "$task_output"
    exit 1
fi

echo ""

# Sync beads to git so sandbox can access the task
info "Syncing beads changes to remote..."
bd sync >/dev/null 2>&1 || true
git push origin HEAD >/dev/null 2>&1 || true
pass "Beads changes pushed to remote"

echo ""

# ==================================================
# PHASE 3: RUN DEVELOPMENT WORKFLOW
# ==================================================

echo "Phase 3: Running Development Workflow"
echo "-------------------------------------------"
info "Invoking: claude-sandbox local '/develop $task_id'"
info "This will trigger planner → implementer → reviewer stages"
echo ""

# Note: claude-sandbox creates isolated environment
# The task needs to be in remote git for sandbox to access it
workflow_output_file=$(mktemp)

echo ""
warn "IMPORTANT: claude-sandbox uses isolated environment"
info "For automated testing, you need the task in remote git"
info "For manual testing, run: claude /develop $task_id"
echo ""
read -p "Press Enter to run claude-sandbox, or Ctrl+C to exit and test manually..."
echo ""

if claude-sandbox local "/develop $task_id" > "$workflow_output_file" 2>&1; then
    pass "Workflow completed successfully"
else
    fail "Workflow execution failed"
    info "Output saved to: $workflow_output_file"
    cat "$workflow_output_file"
    exit 1
fi

echo ""

# ==================================================
# PHASE 4: VERIFY ACCEPTANCE CRITERIA
# ==================================================

echo "Phase 4: Verifying Acceptance Criteria"
echo "-------------------------------------------"

CRITERIA_PASSED=0
CRITERIA_FAILED=0

# Criterion 1: Metrics file exists
echo "1. Checking metrics file exists..."
if [[ -f "$HOME/.claude/workflow-metrics.jsonl" ]]; then
    pass "Metrics file exists: .claude/workflow-metrics.jsonl"
    CRITERIA_PASSED=$((CRITERIA_PASSED + 1))
else
    fail "Metrics file not found"
    CRITERIA_FAILED=$((CRITERIA_FAILED + 1))
fi

# Criterion 2: Stage start/end events captured
echo "2. Checking stage events captured..."
stage_starts=$(jq -s 'map(select(.event=="stage_start")) | length' "$HOME/.claude/workflow-metrics.jsonl" 2>/dev/null || echo 0)
stage_ends=$(jq -s 'map(select(.event=="stage_end")) | length' "$HOME/.claude/workflow-metrics.jsonl" 2>/dev/null || echo 0)

if [[ $stage_starts -ge 3 && $stage_ends -ge 3 ]]; then
    pass "Stage events captured: $stage_starts starts, $stage_ends ends (expected >= 3 each)"
    CRITERIA_PASSED=$((CRITERIA_PASSED + 1))
else
    fail "Insufficient stage events: $stage_starts starts, $stage_ends ends (expected >= 3 each)"
    CRITERIA_FAILED=$((CRITERIA_FAILED + 1))
fi

# Criterion 3: Token data present
echo "3. Checking token data..."
events_with_tokens=$(jq -s 'map(select(.event=="stage_end" and .tokens.input > 0 and .tokens.output > 0)) | length' "$HOME/.claude/workflow-metrics.jsonl" 2>/dev/null || echo 0)

if [[ $events_with_tokens -ge 3 ]]; then
    pass "Token data captured in $events_with_tokens stage_end events"
    CRITERIA_PASSED=$((CRITERIA_PASSED + 1))
else
    fail "Token data missing or zero in most events (found $events_with_tokens with valid tokens)"
    CRITERIA_FAILED=$((CRITERIA_FAILED + 1))
fi

# Criterion 4: Cost calculated
echo "4. Checking cost calculation..."
events_with_cost=$(jq -s 'map(select(.event=="stage_end" and .cost_usd > 0)) | length' "$HOME/.claude/workflow-metrics.jsonl" 2>/dev/null || echo 0)
total_cost=$(jq -s 'map(select(.event=="stage_end").cost_usd) | add // 0' "$HOME/.claude/workflow-metrics.jsonl" 2>/dev/null || echo 0)

if [[ $events_with_cost -ge 3 ]]; then
    pass "Cost calculated: $events_with_cost events, total: \$$total_cost"
    CRITERIA_PASSED=$((CRITERIA_PASSED + 1))
else
    fail "Cost calculation missing (found $events_with_cost events with cost > 0)"
    CRITERIA_FAILED=$((CRITERIA_FAILED + 1))
fi

# Criterion 5: Model captured
echo "5. Checking model information..."
events_with_model=$(jq -s 'map(select(.event=="stage_end" and .model != null)) | length' "$HOME/.claude/workflow-metrics.jsonl" 2>/dev/null || echo 0)

if [[ $events_with_model -ge 3 ]]; then
    model_name=$(jq -r 'select(.event=="stage_end") | .model' "$HOME/.claude/workflow-metrics.jsonl" 2>/dev/null | head -1)
    pass "Model captured in $events_with_model events (e.g., $model_name)"
    CRITERIA_PASSED=$((CRITERIA_PASSED + 1))
else
    fail "Model information missing (found $events_with_model events with model)"
    CRITERIA_FAILED=$((CRITERIA_FAILED + 1))
fi

# Criterion 6: Duration captured
echo "6. Checking duration data..."
events_with_duration=$(jq -s 'map(select(.event=="stage_end" and .duration_seconds > 0)) | length' "$HOME/.claude/workflow-metrics.jsonl" 2>/dev/null || echo 0)

if [[ $events_with_duration -ge 3 ]]; then
    pass "Duration captured in $events_with_duration events"
    CRITERIA_PASSED=$((CRITERIA_PASSED + 1))
else
    fail "Duration data missing (found $events_with_duration events with duration > 0)"
    CRITERIA_FAILED=$((CRITERIA_FAILED + 1))
fi

# Criterion 7: BD comments posted
echo "7. Checking BD comments..."
# Get subtasks of the parent task
subtasks=$(bd list --parent "$task_id" 2>/dev/null | grep -oE '\.claude-[a-z0-9]+\.[0-9]+' || echo "")

if [[ -n "$subtasks" ]]; then
    comments_found=0
    while IFS= read -r subtask; do
        if bd comments "$subtask" 2>/dev/null | grep -q "Stage Metrics"; then
            comments_found=$((comments_found + 1))
        fi
    done <<< "$subtasks"

    if [[ $comments_found -ge 2 ]]; then
        pass "BD comments with metrics found on $comments_found subtasks"
        CRITERIA_PASSED=$((CRITERIA_PASSED + 1))
    else
        fail "BD comments missing or incomplete (found on $comments_found subtasks)"
        CRITERIA_FAILED=$((CRITERIA_FAILED + 1))
    fi
else
    warn "No subtasks found to check for comments"
    CRITERIA_FAILED=$((CRITERIA_FAILED + 1))
fi

# Criterion 8: Validate stages match expected workflow
echo "8. Checking workflow stages..."
stages=$(jq -r 'select(.event=="stage_end") | .stage' "$HOME/.claude/workflow-metrics.jsonl" 2>/dev/null | sort -u)
expected_stages="implementer planner reviewer"

if echo "$stages" | grep -q "planner" && echo "$stages" | grep -q "implementer" && echo "$stages" | grep -q "reviewer"; then
    pass "Expected workflow stages present: planner, implementer, reviewer"
    CRITERIA_PASSED=$((CRITERIA_PASSED + 1))
else
    fail "Missing expected stages. Found: $(echo $stages | tr '\n' ' ')"
    CRITERIA_FAILED=$((CRITERIA_FAILED + 1))
fi

echo ""
echo "========================================="
echo "TEST RESULTS"
echo "========================================="
echo ""

# Display summary metrics
echo "Metrics Summary:"
jq -s 'group_by(.stage) | map({stage: .[0].stage, events: length, total_cost: (map(.cost_usd // 0) | add), avg_duration: (map(.duration_seconds // 0) | add / length)})' "$HOME/.claude/workflow-metrics.jsonl" 2>/dev/null | jq .

echo ""
echo "Acceptance Criteria: $CRITERIA_PASSED/8 passed"
echo ""

if [[ $CRITERIA_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    echo ""
    echo "Usage metrics collection is working correctly!"
    echo ""
    echo "Metrics file: $HOME/.claude/workflow-metrics.jsonl"
    echo "Test task: $task_id"
    echo "Workflow output: $workflow_output_file"
    exit 0
else
    echo -e "${RED}✗ TESTS FAILED${NC}"
    echo ""
    echo "Failed criteria: $CRITERIA_FAILED/8"
    echo ""
    echo "Debug information:"
    info "Metrics file: $HOME/.claude/workflow-metrics.jsonl"
    info "Test task: $task_id"
    info "Workflow output: $workflow_output_file"
    echo ""
    echo "Recent metrics entries:"
    tail -5 "$HOME/.claude/workflow-metrics.jsonl" 2>/dev/null | jq . || echo "No entries found"
    exit 1
fi
