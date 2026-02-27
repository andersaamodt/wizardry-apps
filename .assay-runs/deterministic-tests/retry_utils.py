import time
def retry_with_exponential_backoff(max_retries=3, initial_delay=1, factor=2):
    def decorator(func):
        def wrapper(*args, **kwargs):
            attempt = 0
            while attempt < max_retries:
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    delay = initial_delay * (factor ** attempt)
                    print(f"Attempt {attempt + 1} failed. Retrying in {delay:.2f}s...")
                    time.sleep(delay)
                    attempt += 1
            raise
        return wrapper
    return decorator