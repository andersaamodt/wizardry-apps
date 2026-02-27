// This script introduces a race condition to demonstrate the issue and then fixes it using locks.
const { Lock } = require('async-lock');
const lock = new Lock();
let sharedResource = 0;
function simulateWork() {
  return new Promise((resolve) => {
    setTimeout(() => {
      sharedResource += 1;
      resolve(sharedResource);
    }, Math.random() * 100);
  });
}
async function workerThread() {
  await lock.acquire('resource', async () => {
    const result = await simulateWork();
    console.log(`Worker updated resource to: ${result}`);
  });
}
function main() {
  for (let i = 0; i < 10; i++) {
    workerThread().catch(console.error);
  }
}
main();