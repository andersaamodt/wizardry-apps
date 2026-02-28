class FallbackHandler:
    def __init__(self, fallback_func):
        self.fallback_func = fallback_func

    def handle(self, func, *args, **kwargs):
        try:
            return func(*args, **kwargs)
        except Exception as e:
            print(f"Primary function failed: {e}")
            return self.fallback_func()

