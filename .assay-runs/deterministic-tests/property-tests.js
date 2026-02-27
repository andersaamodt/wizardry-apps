const { runWithSeed } = require('./repeatable-seed-control');
function runPropertyTests() {
  const seeds = [12345, 67890, 54321];
  seeds.forEach(seed => {
    const result = runWithSeed(seed);
    if (result !== expectedResults[seed]) {
      console.error(`Test failed for seed ${seed}: Expected ${expectedResults[seed]}, got ${result}`);
      return false;
    }
  });
  return true;
}
const expectedResults = {
  12345: 'expected_result_1',
  67890: 'expected_result_2',
  54321: 'expected_result_3'
};
module.exports = { runPropertyTests };