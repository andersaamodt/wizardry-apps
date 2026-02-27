import time

class DependencyManager:
    def __init__(self, max_retries=3, retry_interval=5):
        self.max_retries = max_retries
        self.retry_interval = retry_interval

    def fetch_dependency(self, path):
        for attempt in range(1, self.max_retries + 1):
            try:
                return self._fetch_dependency(path)
            except Exception as e:
                print(f"Attempt {attempt} failed: {e}")
                if attempt < self.max_retries:
                    time.sleep(self.retry_interval)
        raise Exception(f"All {self.max_retries} attempts failed")

    def _fetch_dependency(self, path):
        # Simulate dependency fetch
        if path == "nonexistent_path":
            raise Exception("Path does not exist")
        return f"Dependency at {path}"
