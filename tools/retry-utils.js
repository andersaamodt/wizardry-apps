function retryWithFallback(maxRetries, delay, fallbackFunction) {
  return async function (func, ...args) {
    let retries = maxRetries;
    while (retries > 0) {
      try {
        return await func(...args);
      } catch (error) {
        retries--;
        if (retries === 0) {
          console.error(`Max retries reached. Fallback to:`, fallbackFunction);
          return await fallbackFunction();
        }
        await new Promise(resolve => setTimeout(resolve,