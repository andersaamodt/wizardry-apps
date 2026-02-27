#!/bin/bash
# Validate the manifest files in the config directory
MANIFEST_DIR="/Users/andersaamodt/git/wizardry-apps/config"
for file in "${MANIFEST_DIR}"/*.manifest.json; do
  jq . "$file" &> /dev/null
  if [ $? -ne 0 ]; then
    echo "Manifest validation failed for ${file}"
    exit 1
  fi
done
echo "All manifest files are valid"