const { formatTimestamp } = require('./time-formatter');

console.log('Running timestamp formatter tests...\n');

// Test 1: Valid date object with known value
const result1 = formatTimestamp(new Date('2024-01-15'));
if (result1 === '2024-01-15T00:00:00.000Z') {
  console.log('✓ Test 1 passed:', result1);
} else {
  console.error('✗ Test 1 failed: Expected "2024-01-15T00:00:00.000Z" but got:', result1);
}

// Test 2: Current date - validate format, not exact value
const result2 = formatTimestamp(new Date());
const isoFormatRegex = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;
if (isoFormatRegex.test(result2)) {
  console.log('✓ Test 2 passed: Current date returns valid ISO format:', result2);
} else {
  console.error('✗ Test 2 failed: Expected ISO format but got:', result2);
}

// Test 3: Null input - validate format, not exact value
const result3 = formatTimestamp(null);
if (isoFormatRegex.test(result3)) {
  console.log('✓ Test 3 passed: Null returns valid ISO format:', result3);
} else {
  console.error('✗ Test 3 failed: Expected ISO format but got:', result3);
}

// Test 4: Undefined input - validate format, not exact value
const result4 = formatTimestamp(undefined);
if (isoFormatRegex.test(result4)) {
  console.log('✓ Test 4 passed: Undefined returns valid ISO format:', result4);
} else {
  console.error('✗ Test 4 failed: Expected ISO format but got:', result4);
}

// Test 5: No argument - validate format, not exact value
const result5 = formatTimestamp();
if (isoFormatRegex.test(result5)) {
  console.log('✓ Test 5 passed: No argument returns valid ISO format:', result5);
} else {
  console.error('✗ Test 5 failed: Expected ISO format but got:', result5);
}

// Test 6: Invalid date - validate format, not exact value
const result6 = formatTimestamp(new Date('invalid'));
if (isoFormatRegex.test(result6)) {
  console.log('✓ Test 6 passed: Invalid date returns valid ISO format:', result6);
} else {
  console.error('✗ Test 6 failed: Expected ISO format but got:', result6);
}

console.log('\nAll tests completed!');
