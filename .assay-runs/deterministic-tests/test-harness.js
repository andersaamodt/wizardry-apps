const { spawn } = require('child_process');
const fs = require('fs');

function runWithSeed(seed) {
  const env = { ...process.env, SEED: seed };
  return new Promise((resolve, reject) => {
    const child = spawn('npm', ['test'], { env });
    let output = '';

    child.stdout.on('data', (chunk) => {
      output += chunk.toString();
    });

    child.stderr.on('data', (chunk) => {
      output += chunk.toString();
      reject(new Error(output));
    });

    child.on('close', (code) => {
      if (code !== 0) {
        reject(new Error(`Test failed with code ${code}: ${output}`));
      } else {
        resolve(output);
      }
    });
  });
}

async function runTests(seed = Math.floor(Math.random() * 1000)) {
  try {
    const result = await runWithSeed(seed);
    console.log(`Test passed with seed ${seed}:`);
    console.log(result);
  } catch (error) {
    console.error(error.message);
  }
}

module.exports = { runTests };
