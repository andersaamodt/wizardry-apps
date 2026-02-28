const { performance } = require('perf_hooks');
const { execSync } = require('child_process');
// Function to simulate a race condition by running commands concurrently
async function runConcurrently(command1, command2) {
  const start = performance.now();
  // Run the first command in a subprocess
  const child1 = execSync(command1, { encoding: 'utf8', stdio: 'pipe' });
  // Run the second command in another subprocess
  const child2 = execSync(command2, { encoding: 'utf8', stdio: 'pipe' });
  const end = performance.now();
  console.log(`Total time taken for both commands to complete concurrently: ${end - start} ms`);
}
// Example commands that might cause a race condition
const command1 = 'node tools/sync-from-wizardry.sh';
const command2 = 'node tools/test-harness.js';
runConcurrently(command1, command2);