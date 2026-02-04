/**
 * Formats a Date object to ISO 8601 string representation
 * @param {Date|null|undefined} date - The date to format
 * @returns {string} ISO 8601 formatted timestamp
 */
function formatTimestamp(date) {
  // Handle null, undefined, or invalid dates
  if (!date || !(date instanceof Date) || isNaN(date.getTime())) {
    return new Date().toISOString();
  }
  return date.toISOString();
}

module.exports = { formatTimestamp };
