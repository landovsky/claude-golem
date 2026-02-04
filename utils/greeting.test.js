const { greet } = require('./greeting');

console.log('Running greeting utility tests...\n');

// Test 1: Basic greeting
try {
  const result = greet('Alice');
  console.log('✓ Test 1 passed:', result);
} catch (e) {
  console.error('✗ Test 1 failed:', e.message);
}

// Test 2: Another name
try {
  const result = greet('Bob');
  console.log('✓ Test 2 passed:', result);
} catch (e) {
  console.error('✗ Test 2 failed:', e.message);
}

// Test 3: Empty string should throw
try {
  greet('');
  console.error('✗ Test 3 failed: Should have thrown error for empty string');
} catch (e) {
  console.log('✓ Test 3 passed: Correctly rejected empty string');
}

// Test 4: Non-string should throw
try {
  greet(123);
  console.error('✗ Test 4 failed: Should have thrown error for non-string');
} catch (e) {
  console.log('✓ Test 4 passed: Correctly rejected non-string input');
}

console.log('\nAll tests completed!');
