const retryUtils = require('./retry-utils');
async function getExternalData(path) {
  try {
    const response = await fetch(`http://${path}`);
    if (!response.ok) {
      throw new Error('Failed to fetch external data');
    }
    return await response.json();
  } catch (error) {
    console.error(`Error fetching from ${path}:`, error);
    throw error;
  }
}
async function getExternalDataWithRetry(path, fallbackPath) {
  return await retryUtils.retryWithFallback(
    () => getExternalData(path),
    () => getExternalData(fallbackPath)
  );
}