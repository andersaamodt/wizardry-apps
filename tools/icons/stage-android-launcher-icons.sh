#!/bin/sh

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: stage-android-launcher-icons.sh APP_DIR RES_DIR

Copies generated Android launcher icons into the Android host resource tree.
USAGE
  exit 0
  ;;
esac

set -eu

app_dir=${1-}
res_dir=${2-}

if [ -z "$app_dir" ] || [ -z "$res_dir" ]; then
  printf '%s\n' "stage-android-launcher-icons: APP_DIR and RES_DIR are required" >&2
  exit 2
fi

icons_dir="$app_dir/assets/icons/android"
source_icon="$app_dir/assets/forge-icon.png"

for folder in mipmap-mdpi mipmap-hdpi mipmap-xhdpi mipmap-xxhdpi mipmap-xxxhdpi; do
  mkdir -p "$res_dir/$folder"
  if [ -d "$icons_dir/$folder" ]; then
    cp "$icons_dir/$folder"/ic_launcher*.png "$res_dir/$folder/"
    continue
  fi
  [ -f "$source_icon" ] || continue
  cp "$source_icon" "$res_dir/$folder/ic_launcher.png"
  cp "$source_icon" "$res_dir/$folder/ic_launcher_round.png"
done
