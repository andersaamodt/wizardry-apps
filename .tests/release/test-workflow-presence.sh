#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)

for wf in \
  ci-lint.yml \
  ci-tests.yml \
  ci-core-parity.yml \
  build-desktop.yml \
  build-mobile.yml \
  build-hosted-web.yml \
  build-godot.yml \
  release.yml \
  promote-stores.yml \
  sync-from-wizardry.yml
 do
  [ -f "$ROOT_DIR/.github/workflows/$wf" ] || {
    printf '%s\n' "missing workflow: $wf" >&2
    exit 1
  }
 done

printf '%s\n' "workflow presence checks passed"
