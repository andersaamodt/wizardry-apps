import traceback

class FailureDiagnostic:
    @staticmethod
    def diagnose(func, *args, **kwargs):
        try:
            return func(*args, **kwargs)
        except Exception as e:
            print(f"Exception occurred: {e}")
            print("Traceback:")
            traceback.print_exc()
            raise

