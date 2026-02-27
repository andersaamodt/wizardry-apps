const externalDependencyManager = require('./external-dependency-manager');
async function fetchAndProcessData() {
  const path = 'external-service.com/data';
  const fallbackPath = 'backup-external-service.com/data';
  try {
    const data = await externalDependencyManager.getExternalDataWithRetry(path, fallbackPath);
    console.log('Data fetched successfully:', data);
  } catch (error) {
    console.error('Failed to fetch and process data:', error);
  }
}
fetchAndProcessData();