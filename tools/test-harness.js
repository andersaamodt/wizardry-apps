const assert = require('assert');
const { runForge } = require('../run-forge');
describe('Forge Module', function() {
  it('should complete without errors', async function() {
    const seed = Math.floor(Date.now()