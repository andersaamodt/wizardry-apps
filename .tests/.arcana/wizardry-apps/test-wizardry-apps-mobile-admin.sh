#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-apps-mobile-admin.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

cat >"$tmp_dir/menu" <<'SH'
#!/bin/sh
printf '%s\n' "$@" >"${MENU_LOG:?}"
exit 130
SH
chmod +x "$tmp_dir/menu"

MENU_LOG="$tmp_dir/menu.log" WIZARDRY_DIR="$HOME/.wizardry" PATH="$HOME/.wizardry/spells:$HOME/.wizardry/spells/.imps:$HOME/.wizardry/spells/.imps/menu:$HOME/.wizardry/spells/.imps/sys:$tmp_dir:/bin:/usr/bin" MENU_BIN="$tmp_dir/menu" MENU_LOG="$tmp_dir/menu.log" \
  sh "$ROOT_DIR/spells/.arcana/wizardry-apps/wizardry-apps-mobile-admin"

grep -F "Mobile debugging" "$tmp_dir/menu.log" >/dev/null

printf '%s\n' "wizardry-apps mobile admin checks passed"
