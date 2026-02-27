#!/bin/bash
# Sync files from the wizardry-apps monorepo to the target directory
SOURCE_DIR="/Users/andersaamodt/git/wizardry-apps"
TARGET_DIR="/path/to/target/directory"
cp -r "${SOURCE_DIR}/*" "${TARGET_DIR}/"