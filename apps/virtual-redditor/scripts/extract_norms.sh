#!/bin/sh

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: extract_norms.sh

Runs the Virtual Redditor nightly statute extraction pass once,
using Ollama to propose and accept norms into norms.jsonl.
USAGE
  exit 0
  ;;
esac

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
exec "$SCRIPT_DIR/virtual-redditor-daemon.sh" extract-norms "$@"
