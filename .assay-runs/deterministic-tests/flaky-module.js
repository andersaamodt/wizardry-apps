const seedrandom = require('seedrandom');
function run() {
  // Example of a flaky module that uses random numbers
  const rng = seedrandom(Math.random());
  const randomNumber = Math.floor(rng() * 10);
  if (randomNumber % 2 === 0) {
    return 'expected_result_1';
  } else {
    return 'expected_result_2';
  }
}
module.exports = { run };