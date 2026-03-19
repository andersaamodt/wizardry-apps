#!/bin/sh

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: generate-platform-icons.sh INPUT_IMAGE PROJECT_DIR [--squircle|--plain]

Generates normalized icon assets for Forge across supported platforms.
USAGE
  exit 0
  ;;
esac

set -eu

input_image=${1-}
project_dir=${2-}
shape_flag=${3---squircle}

if [ -z "$input_image" ] || [ -z "$project_dir" ]; then
  printf '%s\n' "generate-platform-icons: INPUT_IMAGE and PROJECT_DIR are required" >&2
  exit 2
fi

[ -f "$input_image" ] || {
  printf '%s\n' "generate-platform-icons: input image not found: $input_image" >&2
  exit 1
}

[ -d "$project_dir" ] || {
  printf '%s\n' "generate-platform-icons: project directory not found: $project_dir" >&2
  exit 1
}

command -v magick >/dev/null 2>&1 || {
  printf '%s\n' "generate-platform-icons: ImageMagick (magick) is required" >&2
  exit 1
}

use_squircle=1
case "$shape_flag" in
  --squircle|'') use_squircle=1 ;;
  --plain) use_squircle=0 ;;
  *)
    printf '%s\n' "generate-platform-icons: unknown option: $shape_flag" >&2
    exit 2
    ;;
esac

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/wizardry-icon-pipeline.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

assets_dir="$project_dir/assets"
icons_dir="$assets_dir/icons"
macos_dir="$icons_dir/macos"
linux_dir="$icons_dir/linux"
android_dir="$icons_dir/android"
ios_dir="$icons_dir/ios/AppIcon.appiconset"
web_dir="$icons_dir/web"
meta_dir="$icons_dir/meta"

mkdir -p "$assets_dir" "$macos_dir" "$linux_dir" "$android_dir" "$ios_dir" "$web_dir" "$meta_dir"

plain_master="$tmp_dir/plain-master.png"
apple_base="$tmp_dir/apple-base.png"
primary_master="$tmp_dir/primary-master.png"
trimmed_source="$tmp_dir/trimmed-source.png"
subject_master="$tmp_dir/subject-master.png"
shadow_master="$tmp_dir/shadow-master.png"
shadow_alpha="$tmp_dir/shadow-alpha.png"
subject_size=820

magick "$input_image" \
  -auto-orient \
  -background none \
  -alpha on \
  -trim +repage \
  "$trimmed_source"

if [ ! -s "$trimmed_source" ]; then
  cp "$input_image" "$trimmed_source"
fi

magick "$trimmed_source" \
  -background none \
  -alpha on \
  -resize "${subject_size}x${subject_size}" \
  -gravity center \
  "$subject_master"

magick "$subject_master" \
  -alpha extract \
  -blur 0x10 \
  -level 0,45% \
  "$shadow_alpha"

magick -size 1024x1024 xc:none \
  \( "$shadow_alpha" -background none -gravity center -extent 1024x1024 \) \
  -compose CopyOpacity -composite \
  "$shadow_master"

magick "$shadow_master" \
  -fill "rgba(0,0,0,0.22)" -colorize 100 \
  "$shadow_master"

magick "$shadow_master" \
  \( "$subject_master" -background none -gravity center -extent 1024x1024 \) \
  -gravity center -compose Over -composite \
  -sharpen 0x0.6 \
  -contrast-stretch 2%x2% \
  -gravity center \
  "$plain_master"

if [ "$use_squircle" -eq 1 ]; then
  magick "$plain_master" \
    \( -size 1024x1024 xc:none -fill white -draw "roundrectangle 44,44 980,980 232,232" \) \
    -alpha off -compose CopyOpacity -composite \
    "$apple_base"
  cp "$apple_base" "$primary_master"
else
  cp "$plain_master" "$apple_base"
  cp "$plain_master" "$primary_master"
fi

cp "$primary_master" "$assets_dir/forge-icon.png"
cp "$plain_master" "$meta_dir/plain-master.png"
cp "$apple_base" "$meta_dir/apple-master.png"

rm -rf "$macos_dir/iconset.iconset"
iconset_dir="$macos_dir/iconset.iconset"
mkdir -p "$iconset_dir"
for size in 16 32 64 128 256 512; do
  magick "$apple_base" -resize "${size}x${size}" "$iconset_dir/icon_${size}x${size}.png"
  magick "$apple_base" -resize "$((size * 2))x$((size * 2))" "$iconset_dir/icon_${size}x${size}@2x.png"
done
if command -v iconutil >/dev/null 2>&1; then
  iconutil -c icns "$iconset_dir" -o "$macos_dir/forge.icns" >/dev/null 2>&1 || true
fi

for size in 16 32 48 64 128 256 512; do
  out_dir="$linux_dir/${size}x${size}"
  mkdir -p "$out_dir"
  magick "$plain_master" -resize "${size}x${size}" "$out_dir/forge-icon.png"
done

android_resize() {
  size=$1
  folder=$2
  mkdir -p "$android_dir/$folder"
  magick "$primary_master" -resize "${size}x${size}" "$android_dir/$folder/ic_launcher.png"
  magick "$primary_master" -resize "${size}x${size}" "$android_dir/$folder/ic_launcher_round.png"
}

android_resize 48 mipmap-mdpi
android_resize 72 mipmap-hdpi
android_resize 96 mipmap-xhdpi
android_resize 144 mipmap-xxhdpi
android_resize 192 mipmap-xxxhdpi

ios_icon() {
  point=$1
  scale=$2
  idiom=$3
  filename=$4
  pixels=$(awk "BEGIN { printf \"%d\", ($point * $scale) + 0.5 }")
  magick "$apple_base" -resize "${pixels}x${pixels}" "$ios_dir/$filename"
  printf '      {\n'
  printf '        "size": "%sx%s",\n' "$point" "$point"
  printf '        "idiom": "%s",\n' "$idiom"
  printf '        "filename": "%s",\n' "$filename"
  printf '        "scale": "%sx"\n' "$scale"
  printf '      }'
}

{
  printf '{\n'
  printf '  "images" : [\n'
  ios_icon 20 2 iphone "icon-20@2x.png"; printf ',\n'
  ios_icon 20 3 iphone "icon-20@3x.png"; printf ',\n'
  ios_icon 29 2 iphone "icon-29@2x.png"; printf ',\n'
  ios_icon 29 3 iphone "icon-29@3x.png"; printf ',\n'
  ios_icon 40 2 iphone "icon-40@2x.png"; printf ',\n'
  ios_icon 40 3 iphone "icon-40@3x.png"; printf ',\n'
  ios_icon 60 2 iphone "icon-60@2x.png"; printf ',\n'
  ios_icon 60 3 iphone "icon-60@3x.png"; printf ',\n'
  ios_icon 20 1 ipad "icon-20@1x-ipad.png"; printf ',\n'
  ios_icon 20 2 ipad "icon-20@2x-ipad.png"; printf ',\n'
  ios_icon 29 1 ipad "icon-29@1x-ipad.png"; printf ',\n'
  ios_icon 29 2 ipad "icon-29@2x-ipad.png"; printf ',\n'
  ios_icon 40 1 ipad "icon-40@1x-ipad.png"; printf ',\n'
  ios_icon 40 2 ipad "icon-40@2x-ipad.png"; printf ',\n'
  ios_icon 76 1 ipad "icon-76@1x-ipad.png"; printf ',\n'
  ios_icon 76 2 ipad "icon-76@2x-ipad.png"; printf ',\n'
  ios_icon 83.5 2 ipad "icon-83.5@2x-ipad.png"; printf ',\n'
  ios_icon 1024 1 ios-marketing "icon-1024.png"; printf '\n'
  printf '  ],\n'
  printf '  "info" : {\n'
  printf '    "author" : "wizardry",\n'
  printf '    "version" : 1\n'
  printf '  }\n'
  printf '}\n'
} > "$ios_dir/Contents.json"

for size in 32 64 180 192 512; do
  magick "$primary_master" -resize "${size}x${size}" "$web_dir/icon-${size}.png"
done
cp "$web_dir/icon-32.png" "$web_dir/favicon.png"
cp "$web_dir/icon-180.png" "$web_dir/apple-touch-icon.png"

cat > "$meta_dir/icon-settings.conf" <<CONF
generator=wizardry-forge-icon-pipeline
squircle=$use_squircle
master=$assets_dir/forge-icon.png
plain_master=$meta_dir/plain-master.png
apple_master=$meta_dir/apple-master.png
CONF

printf 'icon=%s\n' "$assets_dir/forge-icon.png"
printf 'status=%s\n' "updated"
printf 'squircle=%s\n' "$use_squircle"
printf 'macos_icns=%s\n' "$macos_dir/forge.icns"
printf 'linux_dir=%s\n' "$linux_dir"
printf 'android_dir=%s\n' "$android_dir"
printf 'ios_dir=%s\n' "$ios_dir"
printf 'web_dir=%s\n' "$web_dir"
