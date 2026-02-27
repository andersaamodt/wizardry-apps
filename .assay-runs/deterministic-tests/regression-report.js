const { runPropertyTests } = require('./property-tests');
function generateRegressionReport() {
  const success = runPropertyTests();
  if (success) {
    console.log('All property tests passed successfully.');
  } else {
    console.error('One or more property tests failed. Please review the results and make necessary adjustments.');
  }
}
module.exports = { generateRegressionReport };