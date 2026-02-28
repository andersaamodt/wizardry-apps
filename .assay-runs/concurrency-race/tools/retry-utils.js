// No changes needed for this file as it's not involved in the race condition simulation
module.exports = {
  retryOperation: (operation, maxRetries) => {
    let retries = 0;
    while (retries < maxRetries) {
      try {
        return operation();
      } catch (error) {
        retries++;
        console.log(`Retry ${retries} failed. Retrying...`);
      }
    }
    throw new Error("Operation failed after maximum retries");
  }
};