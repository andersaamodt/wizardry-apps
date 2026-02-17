#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
out=$(sh "$ROOT_DIR/tools/release/promote-ios-release.sh" --help)
printf '%s' "$out" | grep -q 'Promotes a TestFlight build'
printf '%s' "$out" | grep -q 'IOS_SUBMIT_FOR_REVIEW'

printf '%s\n' "ios promotion script help checks passed"
