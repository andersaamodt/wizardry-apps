import threading

class Counter:
    def __init__(self):
        self.value = 0

    def increment(self):
        for _ in range(1000):
            self.value += 1

def worker(counter):
    counter.increment()

def main():
    counter = Counter()
    threads = [threading.Thread(target=worker, args=(counter,)) for _ in range(10)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    print(f"Final value: {counter.value}")

if __name__ == "__main__":
    main()
