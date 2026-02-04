# Spec: Timestamp Formatter Utility

## Summary
Create a utility function that formats Date objects to ISO 8601 strings, with graceful handling of null/undefined inputs by returning the current time. This validates the metrics collection pipeline while exercising the full workflow.

## Requirements
- [ ] Create `/workspace/utils/time-formatter.js`
- [ ] Export function `formatTimestamp(date)` that returns ISO 8601 string
- [ ] Handle null input: return current time as ISO string
- [ ] Handle undefined input: return current time as ISO string
- [ ] Handle valid Date objects: return their ISO string representation
- [ ] Handle invalid Date objects (e.g., `new Date('invalid')`): return current time
- [ ] Use `Date.prototype.toISOString()` for formatting (standard API)

## Edge cases
- [ ] `formatTimestamp(null)` - returns current time ISO string
- [ ] `formatTimestamp(undefined)` - returns current time ISO string
- [ ] `formatTimestamp()` (no argument) - returns current time ISO string
- [ ] `formatTimestamp(new Date())` - returns that date's ISO string
- [ ] `formatTimestamp(new Date('2024-01-15'))` - returns "2024-01-15T00:00:00.000Z"
- [ ] `formatTimestamp(new Date('invalid'))` - returns current time (isNaN check)

## Acceptance criteria
- [ ] Function exists at `/workspace/utils/time-formatter.js`
- [ ] Function is exported via CommonJS: `module.exports = { formatTimestamp }`
- [ ] All edge cases pass in test file
- [ ] Test file follows existing pattern from `greeting.test.js`
- [ ] JSDoc comments document the function signature

## Out of scope
- Parsing string inputs (only accept Date, null, undefined)
- Custom format strings (only ISO 8601)
- Timezone conversions (toISOString always returns UTC)
- Millisecond precision configuration

## Artifacts consulted
- WORKFLOW.md: Followed process for analyst phase
- lessons-learned.md: No specific warnings about timestamp utilities; noted "over-testing trivial implementations" guidance from .claude-790 run 2

## Artifacts to update
- None required - this is a new utility, not changing existing behavior

## Open risks
- Test timing sensitivity: Tests should check format validity rather than exact match for current-time cases
- $TASK env var may not be set correctly (known issue from .claude-790)
