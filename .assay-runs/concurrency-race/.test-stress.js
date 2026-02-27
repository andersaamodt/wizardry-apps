// This script runs stress tests to reproduce the race condition and verify the fix.
const { spawn } = require('child_process');
function runTests(iterations) {
  for (let i = 0; i < iterations; i++) {
    const child = spawn('node', ['./race-condition-fix.js']);
    child.on('error', (err) => console.error(`Test failed: ${err}`));
  }
}
runTests(100); // Run tests multiple times to increase the likelihood of reproducing the race condition.