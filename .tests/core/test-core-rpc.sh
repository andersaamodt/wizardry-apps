#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)

sh "$ROOT_DIR/runtime/core/tests/test_core.sh"
