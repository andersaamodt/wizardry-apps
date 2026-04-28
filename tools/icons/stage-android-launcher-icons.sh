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
  for icon_name in ic_launcher.png ic_launcher_round.png; do
    generated_icon="$icons_dir/$folder/$icon_name"
    if [ -f "$generated_icon" ]; then
      cp "$generated_icon" "$res_dir/$folder/$icon_name"
    elif [ -f "$source_icon" ]; then
      cp "$source_icon" "$res_dir/$folder/$icon_name"
    fi
  done
done
