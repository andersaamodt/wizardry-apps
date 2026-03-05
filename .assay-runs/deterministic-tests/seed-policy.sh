#!/bin/bash

generate_seed() {
    local seed=$RANDOM
    echo "$seed"
}

echo "Generated Seed: $(generate_seed)"
