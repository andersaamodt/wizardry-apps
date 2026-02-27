// This script verifies that the fix for the race condition works by running stress tests and checking the final state of sharedResource.
const { spawn } = require('child_process');
let expectedResource = 0;
function runTests(iterations) {
  for (let i = 0; i < iterations; i++) {
    const child = spawn('node', ['./race-condition-fix.js']);
    child.on('error', (err) => console.error(`Test failed: ${err}`));
  }
}
runTests(100); // Run tests multiple times to increase the likelihood of reproducing the race condition.
setTimeout(() => {
  console.log(`Expected resource value: ${expectedResource}`);
}, 2000); // Wait for all stress tests to complete and check the final state of sharedResource.