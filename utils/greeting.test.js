const { generateGreeting } = require('./greeting');

console.log('Running greeting utility tests...\n');

// Test 1: Basic greeting with name
const result1 = generateGreeting('Alice');
if (result1 === 'Hello, Alice!') {
  console.log('✓ Test 1 passed:', result1);
} else {
  console.error('✗ Test 1 failed: Expected "Hello, Alice!" but got:', result1);
}

// Test 2: Another name
const result2 = generateGreeting('Bob');
if (result2 === 'Hello, Bob!') {
  console.log('✓ Test 2 passed:', result2);
} else {
  console.error('✗ Test 2 failed: Expected "Hello, Bob!" but got:', result2);
}

// Test 3: Empty string should return Guest
const result3 = generateGreeting('');
if (result3 === 'Hello, Guest!') {
  console.log('✓ Test 3 passed:', result3);
} else {
  console.error('✗ Test 3 failed: Expected "Hello, Guest!" but got:', result3);
}

// Test 4: Null should return Guest
const result4 = generateGreeting(null);
if (result4 === 'Hello, Guest!') {
  console.log('✓ Test 4 passed:', result4);
} else {
  console.error('✗ Test 4 failed: Expected "Hello, Guest!" but got:', result4);
}

// Test 5: Undefined should return Guest
const result5 = generateGreeting(undefined);
if (result5 === 'Hello, Guest!') {
  console.log('✓ Test 5 passed:', result5);
} else {
  console.error('✗ Test 5 failed: Expected "Hello, Guest!" but got:', result5);
}

console.log('\nAll tests completed!');
