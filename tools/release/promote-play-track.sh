#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
repo_root=$(CDPATH= cd -- "$script_dir/../.." && pwd -P)
theurgy_home=${THEURGY_HOME:-$HOME/theurgy}

if [ ! -x "$theurgy_home/tools/release/promote-play-track.sh" ]; then
  "$repo_root/spells/.arcana/theurgy/invoke-theurgy" --yes
fi

export WIZARDRY_APPS_ROOT=${WIZARDRY_APPS_ROOT:-$repo_root}
exec "$theurgy_home/tools/release/promote-play-track.sh" "$@"
