# Usage Metrics Testing Guide

This document captures test cases and validation procedures from the Phase 1 + Phase 2 implementation. These tests can be used for regression testing when making future changes to the metrics system.

## Unit Tests

### Token Parsing (Phase 2)

**Test: Sum tokens across multiple API calls**

```bash
# Create test transcript
cat > /tmp/test-transcript.jsonl <<'EOF'
{"type":"assistant","message":{"model":"claude-sonnet-4-5-20250929","usage":{"input_tokens":100,"output_tokens":50,"cache_read_input_tokens":200,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0}}}}
{"type":"assistant","message":{"model":"claude-sonnet-4-5-20250929","usage":{"input_tokens":150,"output_tokens":75,"cache_read_input_tokens":300,"cache_creation":{"ephemeral_5m_input_tokens":500,"ephemeral_1h_input_tokens":100}}}}
EOF

# Test input token sum
result=$(grep '"type":"assistant"' /tmp/test-transcript.jsonl | \
  jq -s '[.[] | .message.usage.input_tokens // 0] | add // 0')

# Expected: 250 (100 + 150)
[ "$result" -eq 250 ] && echo "✓ Input token sum correct" || echo "✗ Failed: got $result, expected 250"

# Test output token sum
result=$(grep '"type":"assistant"' /tmp/test-transcript.jsonl | \
  jq -s '[.[] | .message.usage.output_tokens // 0] | add // 0')

# Expected: 125 (50 + 75)
[ "$result" -eq 125 ] && echo "✓ Output token sum correct" || echo "✗ Failed: got $result, expected 125"

# Test cache read sum
result=$(grep '"type":"assistant"' /tmp/test-transcript.jsonl | \
  jq -s '[.[] | .message.usage.cache_read_input_tokens // 0] | add // 0')

# Expected: 500 (200 + 300)
[ "$result" -eq 500 ] && echo "✓ Cache read sum correct" || echo "✗ Failed: got $result, expected 500"

# Test cache creation sum (nested fields)
result=$(grep '"type":"assistant"' /tmp/test-transcript.jsonl | \
  jq -s '[.[] | (.message.usage.cache_creation.ephemeral_5m_input_tokens // 0) + (.message.usage.cache_creation.ephemeral_1h_input_tokens // 0)] | add // 0')

# Expected: 600 (0 + 0 + 500 + 100)
[ "$result" -eq 600 ] && echo "✓ Cache creation sum correct" || echo "✗ Failed: got $result, expected 600"
```

**Test: Extract model name**

```bash
# Test model extraction from last message
model=$(grep '"type":"assistant"' /tmp/test-transcript.jsonl | tail -1 | \
  jq -r '.message.model // "null"')

# Expected: claude-sonnet-4-5-20250929
[ "$model" = "claude-sonnet-4-5-20250929" ] && echo "✓ Model extraction correct" || echo "✗ Failed: got $model"
```

### Cost Calculation (Phase 2)

**Test: Sonnet 4 pricing**

```bash
# Input: 10,000 tokens @ $3.00/M = $0.0300
# Output: 5,000 tokens @ $15.00/M = $0.0750
# Cache read: 2,000 tokens @ $0.30/M = $0.0006
# Cache creation: 8,000 tokens @ $3.75/M = $0.0300
# Total: $0.1356

cost=$(awk 'BEGIN {
  cost = (10000 * 3.00 / 1000000) + \
         (5000 * 15.00 / 1000000) + \
         (2000 * 0.30 / 1000000) + \
         (8000 * 3.75 / 1000000)
  printf "%.4f", cost
}')

# Expected: 0.1356
[ "$cost" = "0.1356" ] && echo "✓ Cost calculation correct" || echo "✗ Failed: got $cost, expected 0.1356"
```

**Test: All model pricing tiers**

```bash
# Test pricing table lookup
test_pricing() {
  local model=$1
  local expected_input=$2

  case "$model" in
    *opus-4.5*|*opus-4-5*) rate=5.00 ;;
    *opus-4*) rate=15.00 ;;
    *sonnet-4*) rate=3.00 ;;
    *haiku-4.5*|*haiku-4-5*) rate=1.00 ;;
    *haiku-3.5*|*haiku-3-5*) rate=0.80 ;;
    *) rate=3.00 ;; # fallback
  esac

  [ "$rate" = "$expected_input" ] && echo "✓ $model → $rate" || echo "✗ $model: got $rate, expected $expected_input"
}

test_pricing "claude-opus-4-5-20251101" "5.00"
test_pricing "claude-opus-4-20250514" "15.00"
test_pricing "claude-sonnet-4-5-20250929" "3.00"
test_pricing "claude-haiku-4-5-20250101" "1.00"
test_pricing "claude-haiku-3-5-20241022" "0.80"
test_pricing "claude-unknown-model" "3.00"  # fallback
```

### Duration Calculation (Phase 1)

**Test: Portable date handling**

```bash
# Test BSD date (macOS)
if ! date --version >/dev/null 2>&1; then
  start_time="2026-02-03T14:23:45Z"
  end_time="2026-02-03T14:25:32Z"

  start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$start_time" +%s 2>/dev/null || echo 0)
  end_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$end_time" +%s 2>/dev/null || echo 0)

  duration=$((end_epoch - start_epoch))

  # Expected: 107 seconds (1m 47s)
  [ "$duration" -eq 107 ] && echo "✓ BSD date duration correct" || echo "✗ Failed: got $duration, expected 107"
fi

# Test GNU date (Linux)
if date --version >/dev/null 2>&1; then
  start_time="2026-02-03T14:23:45Z"
  end_time="2026-02-03T14:25:32Z"

  start_epoch=$(date -d "$start_time" +%s 2>/dev/null || echo 0)
  end_epoch=$(date -d "$end_time" +%s 2>/dev/null || echo 0)

  duration=$((end_epoch - start_epoch))

  # Expected: 107 seconds
  [ "$duration" -eq 107 ] && echo "✓ GNU date duration correct" || echo "✗ Failed: got $duration, expected 107"
fi
```

### TASK Truncation (Phase 1)

**Test: 50 character limit**

```bash
long_task="This is a very long task description that exceeds the fifty character limit and should be truncated"
truncated=$(echo "$long_task" | cut -c1-50)

# Expected: "This is a very long task description that excee"
[ "${#truncated}" -eq 50 ] && echo "✓ TASK truncated to 50 chars" || echo "✗ Failed: got ${#truncated} chars"
```

### JSON Generation (Phase 1 + 2)

**Test: jq --arg escaping**

```bash
# Test special characters don't break JSON
dangerous_task='Test "quotes" and $variables and \backslashes'

json=$(jq -nc --arg task "$dangerous_task" '{task: $task}')
extracted=$(echo "$json" | jq -r '.task')

# Should match exactly
[ "$extracted" = "$dangerous_task" ] && echo "✓ jq escaping correct" || echo "✗ Failed: escaping broken"
```

## Edge Cases

### Empty Transcript (Phase 2)

**Expected behavior:** Tokens = 0, cost = null, model = null

```bash
# Create empty transcript
touch /tmp/empty-transcript.jsonl

# Parse with grep + jq (should return 0)
result=$(grep '"type":"assistant"' /tmp/empty-transcript.jsonl 2>/dev/null | \
  jq -s '[.[] | .message.usage.input_tokens // 0] | add // 0')

[ "$result" -eq 0 ] && echo "✓ Empty transcript returns 0" || echo "✗ Failed"
```

### Missing Transcript File (Phase 2)

**Expected behavior:** Graceful fallback to null, exit 0

```bash
# Try to parse non-existent file
result=$(grep '"type":"assistant"' /tmp/nonexistent.jsonl 2>/dev/null | \
  jq -s '[.[] | .message.usage.input_tokens // 0] | add // 0')

[ "$result" -eq 0 ] && echo "✓ Missing file handled gracefully" || echo "✗ Failed"
```

### Malformed JSON (Phase 2)

**Expected behavior:** Skip invalid lines, continue parsing

```bash
# Create transcript with invalid JSON line
cat > /tmp/malformed-transcript.jsonl <<'EOF'
{"type":"assistant","message":{"model":"claude-sonnet-4","usage":{"input_tokens":100}}}
{invalid json here
{"type":"assistant","message":{"model":"claude-sonnet-4","usage":{"input_tokens":200}}}
EOF

# jq should skip malformed line
result=$(grep '"type":"assistant"' /tmp/malformed-transcript.jsonl 2>/dev/null | \
  jq -s '[.[] | .message.usage.input_tokens // 0] | add // 0' 2>/dev/null || echo 0)

# Expected: 300 (100 + 200, skipping malformed line)
[ "$result" -eq 300 ] && echo "✓ Malformed JSON skipped" || echo "✗ Failed: got $result"
```

### Large Token Counts (Phase 2)

**Expected behavior:** jq handles large numbers correctly (no bash arithmetic overflow)

```bash
# Test with 500,000 tokens
cat > /tmp/large-tokens.jsonl <<'EOF'
{"type":"assistant","message":{"usage":{"input_tokens":500000}}}
EOF

result=$(grep '"type":"assistant"' /tmp/large-tokens.jsonl | \
  jq -s '[.[] | .message.usage.input_tokens // 0] | add // 0')

[ "$result" -eq 500000 ] && echo "✓ Large numbers handled correctly" || echo "✗ Failed"
```

### Unknown Model (Phase 2)

**Expected behavior:** Falls back to Sonnet 4 pricing ($3.00 input)

```bash
# Test unknown model fallback
model="claude-unknown-future-model-2027"

case "$model" in
  *opus-4.5*|*opus-4-5*) input_rate=5.00 ;;
  *opus-4*) input_rate=15.00 ;;
  *sonnet-4*) input_rate=3.00 ;;
  *haiku-4.5*|*haiku-4-5*) input_rate=1.00 ;;
  *haiku-3.5*|*haiku-3-5*) input_rate=0.80 ;;
  *) input_rate=3.00 ;; # fallback
esac

[ "$input_rate" = "3.00" ] && echo "✓ Unknown model fallback to Sonnet 4" || echo "✗ Failed"
```

## Integration Tests

### Full Workflow Test (Phase 1 + 2)

**Procedure:**
1. Create a simple beads task
2. Run through full workflow (analyst → planner → implementer → reviewer)
3. Verify JSONL has all stage events
4. Verify BD comments have metrics
5. Verify JSONL schema is valid
6. Verify costs are calculated

```bash
# Step 1: Create test task
task_id=$(bd create "Integration test for metrics" -d "Test Phase 1+2" -p 4 | grep -o '\.claude-[a-z0-9]*')

# Step 2: Run workflow (manual or via /develop)
# ... workflow executes ...

# Step 3: Verify JSONL has all stages
stages=$(jq -r 'select(.event=="stage_end") | .stage' .claude/workflow-metrics.jsonl | sort -u)
echo "Stages captured: $stages"

# Expected: analyst, implementer, planner, reviewer (or subset if fast-track)

# Step 4: Check BD comment
bd show "$task_id.1" | grep "Stage Metrics" && echo "✓ BD comment exists" || echo "✗ No BD comment"

# Step 5: Verify JSONL schema
jq -e 'select(.event=="stage_end") | has("tokens") and has("cost_usd") and has("model")' .claude/workflow-metrics.jsonl && \
  echo "✓ JSONL schema valid" || echo "✗ Schema missing fields"

# Step 6: Verify costs calculated
has_cost=$(jq 'select(.event=="stage_end" and .cost_usd != null)' .claude/workflow-metrics.jsonl | wc -l)
[ "$has_cost" -gt 0 ] && echo "✓ Costs calculated" || echo "✗ No costs found"
```

### Query Compatibility Test (Phase 1 → Phase 2)

**Purpose:** Verify Phase 2 didn't break Phase 1 queries

```bash
# These queries should work on both Phase 1 and Phase 2 data

# Query 1: Filter by stage
jq 'select(.stage=="analyst")' .claude/workflow-metrics.jsonl >/dev/null && \
  echo "✓ Stage filter works" || echo "✗ Failed"

# Query 2: Filter by status
jq 'select(.status=="completed")' .claude/workflow-metrics.jsonl >/dev/null && \
  echo "✓ Status filter works" || echo "✗ Failed"

# Query 3: Aggregate by stage
jq -s 'group_by(.stage) | map({stage: .[0].stage, count: length})' .claude/workflow-metrics.jsonl >/dev/null && \
  echo "✓ Aggregation works" || echo "✗ Failed"
```

## Performance Tests

### Large JSONL File

**Test:** Verify queries perform well with 10,000+ events

```bash
# Generate synthetic data
for i in {1..10000}; do
  echo '{"event":"stage_end","stage":"analyst","duration_seconds":60,"cost_usd":0.05}' >> .claude/workflow-metrics-large.jsonl
done

# Test query speed
time jq 'select(.stage=="analyst")' .claude/workflow-metrics-large.jsonl | wc -l

# Expected: <1 second for filtering 10k events
```

### Concurrent Hook Execution

**Test:** Multiple workflows running in parallel (future enhancement)

**Status:** Not currently supported - requires testing if concurrent subagents are enabled.

## Validation Checklist

Use this checklist when making changes to the metrics system:

### Phase 1 (Infrastructure)
- [ ] Hook scripts are executable (755 permissions)
- [ ] Hooks fire on SubagentStart/SubagentStop
- [ ] JSONL file created on first execution
- [ ] Start/end events correlate by agent_id
- [ ] Duration calculated correctly (portable date handling)
- [ ] Exit 0 always (malformed input doesn't break workflow)
- [ ] BD comments posted (if task ID valid)

### Phase 2 (Token Data)
- [ ] Transcript file parsed successfully
- [ ] Token counts summed across multiple API calls
- [ ] Cache creation tokens aggregated (ephemeral_5m + ephemeral_1h)
- [ ] Model name extracted from last assistant message
- [ ] Cost calculated using correct pricing tier
- [ ] Unknown models fall back to Sonnet 4 pricing
- [ ] Zero tokens handled correctly (null in JSONL)
- [ ] Large numbers (>100k tokens) don't overflow
- [ ] Parsing errors fall back gracefully (null values)

### Backward Compatibility
- [ ] JSONL schema unchanged (Phase 1 queries still work)
- [ ] Zero/null values distinguish "no data" from "no API calls"
- [ ] BD comment format consistent
- [ ] Existing jq queries still work

### Documentation
- [ ] README.md updated with new features
- [ ] Example queries reflect current schema
- [ ] Known limitations documented
- [ ] Troubleshooting section covers common issues

## Test Data Cleanup

```bash
# Remove test files after testing
rm -f /tmp/test-transcript.jsonl
rm -f /tmp/empty-transcript.jsonl
rm -f /tmp/malformed-transcript.jsonl
rm -f /tmp/large-tokens.jsonl
rm -f .claude/workflow-metrics-large.jsonl
```

## Automated Test Suite (Future)

Consider creating a test suite that runs all unit tests automatically:

```bash
#!/bin/bash
# test-metrics.sh

tests_passed=0
tests_failed=0

run_test() {
  if "$@"; then
    tests_passed=$((tests_passed + 1))
  else
    tests_failed=$((tests_failed + 1))
  fi
}

# Run all unit tests
run_test test_token_parsing
run_test test_cost_calculation
run_test test_duration_calculation
run_test test_task_truncation
run_test test_json_escaping
run_test test_empty_transcript
run_test test_missing_file
run_test test_malformed_json
run_test test_large_tokens
run_test test_unknown_model

echo "Tests passed: $tests_passed"
echo "Tests failed: $tests_failed"
[ $tests_failed -eq 0 ] && exit 0 || exit 1
```
