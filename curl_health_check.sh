#!/bin/bash

curl https://example.com/health > health_check.txt
if [ $? -ne 0 ]; then
    echo "Health check failed."
    exit 1
fi
