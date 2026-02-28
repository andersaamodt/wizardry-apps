const { performance } = require('perf_hooks');
async function runTest() {
  const start = performance.now();
  // Simulate a time-consuming operation
  setTimeout(() => {
    console.log("test-harness completed");
  }, 3000);
  const end = performance.now();
  console.log(`Total time taken for test-harness: ${end - start} ms`);
}
runTest();