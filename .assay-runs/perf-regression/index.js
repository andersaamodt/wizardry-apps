const fs = require('fs');
const path = require('path');
function runPerformanceAssays() {
  console.log('[16:04] Starting performance regression analysis...');
  // Step 1: Load baseline data
  const baselineDataPath = path.join(__dirname, 'baseline.json');
  let baselineData;
  try {
    baselineData = JSON.parse(fs.readFileSync(baselineDataPath));
  } catch (e) {
    console.error('[16:05] Error loading baseline data:', e);
    return;
  }
  // Step 2: Execute performance assays
  const assayFiles = fs