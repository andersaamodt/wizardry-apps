module.exports = {
  async retryWithFallback(func, fallbackFunc, retries = 3, delay = 1000) {
    for (let i = 0; i <= retries; i++) {
      try {
        return await func();
      } catch (error) {
        if (i === retries) {
          console.error('All retry attempts failed. Fallback will be executed.');
          return await fallbackFunc();
        }
        console.warn(`Attempt ${i + 1} failed, retrying in ${delay / 1000}s...`);
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
  },
};