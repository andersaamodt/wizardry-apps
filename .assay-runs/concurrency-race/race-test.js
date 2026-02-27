const assert = require('assert');
const { spawn } = require('child_process');

function runStressTest(callback) {
  const stressProcess = spawn('node', ['stress-test-script.js'], { detached: true });
  stressProcess.on('exit', (code, signal) => {
    callback(code, signal);
  });
}

runStressTest((code, signal) => {
  if (code !== 0 || signal) {
    console.error(`Stress test failed with code ${code} and signal ${signal}`);
    process.exit(1);
  }
  console.log('Stress test passed');
  process.exit(0);
});
