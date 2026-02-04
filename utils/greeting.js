/**
 * A simple greeting utility function for testing metrics collection
 * @param {string} name - The name to greet
 * @returns {string} A greeting message
 */
function generateGreeting(name) {
  if (!name) {
    return 'Hello, Guest!';
  }
  return `Hello, ${name}!`;
}

module.exports = { generateGreeting };
