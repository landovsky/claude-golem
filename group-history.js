#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const historyFile = path.join(__dirname, 'history.jsonl');
const outputFile = path.join(__dirname, 'groupped-history.json');

try {
  // Read the JSONL file
  const content = fs.readFileSync(historyFile, 'utf8');
  const lines = content.trim().split('\n');

  // Group by project, then by session
  const grouped = {};

  for (const line of lines) {
    if (!line.trim()) continue;

    try {
      const entry = JSON.parse(line);
      const project = entry.project || 'unknown';
      const sessionId = entry.sessionId || 'no-session';

      // Initialize project if needed
      if (!grouped[project]) {
        grouped[project] = {};
      }

      // Initialize session if needed
      if (!grouped[project][sessionId]) {
        grouped[project][sessionId] = [];
      }

      // Remove project and pastedContents keys
      const { project: _, pastedContents, ...cleanEntry } = entry;

      grouped[project][sessionId].push(cleanEntry);
    } catch (parseError) {
      console.error(`Error parsing line: ${line.substring(0, 50)}...`);
      console.error(parseError.message);
    }
  }

  // Sort items in each session by timestamp (ascending)
  for (const project in grouped) {
    for (const sessionId in grouped[project]) {
      grouped[project][sessionId].sort((a, b) => a.timestamp - b.timestamp);
    }
  }

  // Write the grouped output
  fs.writeFileSync(outputFile, JSON.stringify(grouped, null, 2));

  // Calculate totals
  let totalSessions = 0;
  let totalEntries = 0;
  const projectStats = [];

  for (const [project, sessions] of Object.entries(grouped)) {
    const sessionCount = Object.keys(sessions).length;
    let projectEntries = 0;

    for (const sessionId in sessions) {
      projectEntries += sessions[sessionId].length;
    }

    totalSessions += sessionCount;
    totalEntries += projectEntries;
    projectStats.push({ project, sessions: sessionCount, entries: projectEntries });
  }

  console.log(`✓ Grouped history written to ${outputFile}`);
  console.log(`  Projects found: ${Object.keys(grouped).length}`);
  console.log(`  Total sessions: ${totalSessions}`);
  console.log(`  Total entries: ${totalEntries}`);

  // Show summary sorted by entry count
  console.log('\nSummary:');
  projectStats.sort((a, b) => b.entries - a.entries);
  for (const { project, sessions, entries } of projectStats) {
    console.log(`  ${project}: ${entries} entries in ${sessions} session(s)`);
  }

} catch (error) {
  console.error('Error:', error.message);
  process.exit(1);
}
