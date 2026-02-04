/**
 * A simple greeting utility function for testing metrics collection
 * @param {string} name - The name to greet
 * @returns {string} A greeting message
 */
function greet(name) {
  if (!name || typeof name !== 'string') {
    throw new Error('Name must be a non-empty string');
  }
  return `Hello, ${name}! Welcome to Claude Golem.`;
}

module.exports = { greet };
