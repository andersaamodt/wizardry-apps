const { retry } = require('async-retry');
async function withRetries(fn, retries = 5, delay = 1000) {
    try {
        return await retry(async (bail) => {
            try {
                const result = await fn();
                if (!result.success) {
                    throw new Error(`Operation failed: ${JSON.stringify(result.error)}`);
                }
                return result;
            } catch (error) {
                if (retries === 0) {
                    bail(error);
                } else {
                    retries--;
                    console.warn(`Retrying (${retries} attempts