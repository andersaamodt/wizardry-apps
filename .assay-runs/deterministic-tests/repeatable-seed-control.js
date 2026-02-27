module.exports = {
  runWithSeed(seed) {
    // Set seed for deterministic randomness
    Math.seedrandom(seed);
    // Run your flaky module here
    const result = require('./flaky-module').run();
    return result;
  }
};