#!/bin/bash

# Run performance benchmark for the slow path
/path/to/slow-path-executable --run-benchmark > benchmark.log 2>&1

# Check if benchmark failed
if [ $? -ne 0 ]; then
    echo "Benchmark failed. Check benchmark.log"
    exit 1
fi
