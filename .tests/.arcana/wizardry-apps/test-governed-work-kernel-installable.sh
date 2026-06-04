#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
kernel_arcana="$root/spells/.arcana/governed-work-kernel"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/governed-work-kernel-test.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

for script in \
  _kernel \
  check-governed-work-kernel \
  governed-work-kernel-status \
  governed-work-kernel-menu \
  install-governed-work-kernel \
  uninstall-governed-work-kernel
do
  [ -f "$kernel_arcana/$script" ] || {
    printf '%s\n' "missing governed work kernel script: $script" >&2
    exit 1
  }
  sh -n "$kernel_arcana/$script"
done

fake_upstream="$scratch/upstream"
mkdir -p "$fake_upstream"
cat >"$fake_upstream/Cargo.toml" <<'CARGO'
[workspace]
members = []
CARGO
cat >"$fake_upstream/LICENSE" <<'LICENSE'
GNU Affero General Public License version 3 or later
LICENSE
git -C "$fake_upstream" init >/dev/null
git -C "$fake_upstream" config user.email test@example.invalid
git -C "$fake_upstream" config user.name "Test"
git -C "$fake_upstream" add Cargo.toml LICENSE
git -C "$fake_upstream" commit -m "fake kernel" >/dev/null

XDG_DATA_HOME="$scratch/data" \
XDG_BIN_HOME="$scratch/bin" \
GOVERNED_WORK_KERNEL_SOURCE_URL="$fake_upstream" \
GOVERNED_WORK_KERNEL_SKIP_BUILD=1 \
  "$kernel_arcana/install-governed-work-kernel" >/tmp/governed-work-kernel-install.out

[ -x "$scratch/bin/governed-work-kernel" ]
[ -f "$scratch/data/wizardry-apps/governed-work-kernel/source/Cargo.toml" ]

XDG_DATA_HOME="$scratch/data" XDG_BIN_HOME="$scratch/bin" "$kernel_arcana/check-governed-work-kernel" |
  grep -F "status=ok" >/dev/null

GOVERNED_WORK_KERNEL_SOURCE_DIR="$scratch/data/wizardry-apps/governed-work-kernel/source" \
  "$scratch/bin/governed-work-kernel" status |
  grep -F "license=AGPL-3.0-or-later" >/dev/null

GOVERNED_WORK_KERNEL_SOURCE_DIR="$scratch/data/wizardry-apps/governed-work-kernel/source" \
  "$scratch/bin/governed-work-kernel" source |
  grep -F "$scratch/data/wizardry-apps/governed-work-kernel/source" >/dev/null

grep -F "Governed Work Kernel" "$root/spells/.arcana/wizardry-apps/wizardry-apps-menu" >/dev/null
grep -F "Governed Work Kernel" "$root/spells/.arcana/wizardry-apps/wizardry-apps-status" >/dev/null
grep -F "External AGPL Runtime Dependencies" "$root/.github/WIZARDRY_APPS_LICENSING.md" >/dev/null
grep -F "process/file boundary" "$root/docs/governed-work-kernel.md" >/dev/null

printf '%s\n' "governed work kernel installable tests passed"
