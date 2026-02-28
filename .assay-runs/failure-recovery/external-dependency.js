// external-dependency.js

const { retry } = require('retry');
const fs = require('fs');
const path = require('path');

function resolveDependencyPath(basePath) {
  const dependencyPath = path.join(basePath, 'external_dependency.txt');
  if (!fs.existsSync(dependencyPath)) {
    throw new Error(`External dependency file not found at ${dependencyPath}`);
  }
  return dependencyPath;
}

function loadDependency(filePath) {
  try {
    const data = fs.readFileSync(filePath, 'utf8');
    return JSON.parse(data);
  } catch (error) {
    throw new Error(`Failed to load external dependency from ${filePath}: ${error.message}`);
  }
}

function withRetry(func, options) {
  const operation = retry.operation(options);
  return function () {
    return new Promise((resolve, reject) => {
      operation.attempt(async (currentAttempt) => {
        try {
          resolve(await func());
        } catch (error) {
          if (operation.retry(error)) {
            console.warn(`Attempt ${currentAttempt} failed. Retrying...`);
            return;
          }
          reject(operation.mainError());
        }
      });
    });
  };
}

async function getDependency(basePath, options = { retries: 3, factor: 2 }) {
  try {
    const filePath = await withRetry(() => resolveDependencyPath(basePath), options)();
    return await loadDependency(filePath);
  } catch (error) {
    console.error(`Failed to retrieve external dependency after ${options.retries} attempts:`, error.message);
    throw error;
  }
}

module.exports = getDependency;
