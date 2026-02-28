import time

class RetryHandler:
    def __init__(self, max_retries=3, delay=1):
        self.max_retries = max_retries
        self.delay = delay

    def retry(self, func, *args, **kwargs):
        retries = 0
        while retries < self.max_retries:
            try:
                return func(*args, **kwargs)
            except Exception as e:
                print(f"Attempt {retries + 1} failed: {e}")
                time.sleep(self.delay)
                retries += 1
        raise Exception("Max retries exceeded")

