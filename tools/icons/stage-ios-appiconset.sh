#!/bin/sh

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: stage-ios-appiconset.sh APP_DIR XCSETS_DIR

Copies generated iOS AppIcon assets into the iOS host asset catalog.
USAGE
  exit 0
  ;;
esac

set -eu

app_dir=${1-}
xcassets_dir=${2-}

if [ -z "$app_dir" ] || [ -z "$xcassets_dir" ]; then
  printf '%s\n' "stage-ios-appiconset: APP_DIR and XCSETS_DIR are required" >&2
  exit 2
fi

source_dir="$app_dir/assets/icons/ios/AppIcon.appiconset"
mkdir -p "$xcassets_dir/AppIcon.appiconset"
if [ -d "$source_dir" ]; then
  cp -R "$source_dir"/. "$xcassets_dir/AppIcon.appiconset/"
  exit 0
fi

source_icon="$app_dir/assets/forge-icon.png"
[ -f "$source_icon" ] || exit 0

command -v sips >/dev/null 2>&1 || {
  printf '%s\n' "stage-ios-appiconset: generated icon set missing and sips is unavailable" >&2
  exit 1
}

render_icon() {
  pixels=$1
  filename=$2
  sips -s format png -z "$pixels" "$pixels" "$source_icon" --out "$xcassets_dir/AppIcon.appiconset/$filename" >/dev/null 2>&1
}

render_icon 40 icon-20@2x.png
render_icon 60 icon-20@3x.png
render_icon 58 icon-29@2x.png
render_icon 87 icon-29@3x.png
render_icon 80 icon-40@2x.png
render_icon 120 icon-40@3x.png
render_icon 120 icon-60@2x.png
render_icon 180 icon-60@3x.png
render_icon 20 icon-20@1x-ipad.png
render_icon 40 icon-20@2x-ipad.png
render_icon 29 icon-29@1x-ipad.png
render_icon 58 icon-29@2x-ipad.png
render_icon 40 icon-40@1x-ipad.png
render_icon 80 icon-40@2x-ipad.png
render_icon 76 icon-76@1x-ipad.png
render_icon 152 icon-76@2x-ipad.png
render_icon 167 icon-83.5@2x-ipad.png
render_icon 1024 icon-1024.png

cat > "$xcassets_dir/AppIcon.appiconset/Contents.json" <<'JSON'
{
  "images" : [
    { "size" : "20x20", "idiom" : "iphone", "filename" : "icon-20@2x.png", "scale" : "2x" },
    { "size" : "20x20", "idiom" : "iphone", "filename" : "icon-20@3x.png", "scale" : "3x" },
    { "size" : "29x29", "idiom" : "iphone", "filename" : "icon-29@2x.png", "scale" : "2x" },
    { "size" : "29x29", "idiom" : "iphone", "filename" : "icon-29@3x.png", "scale" : "3x" },
    { "size" : "40x40", "idiom" : "iphone", "filename" : "icon-40@2x.png", "scale" : "2x" },
    { "size" : "40x40", "idiom" : "iphone", "filename" : "icon-40@3x.png", "scale" : "3x" },
    { "size" : "60x60", "idiom" : "iphone", "filename" : "icon-60@2x.png", "scale" : "2x" },
    { "size" : "60x60", "idiom" : "iphone", "filename" : "icon-60@3x.png", "scale" : "3x" },
    { "size" : "20x20", "idiom" : "ipad", "filename" : "icon-20@1x-ipad.png", "scale" : "1x" },
    { "size" : "20x20", "idiom" : "ipad", "filename" : "icon-20@2x-ipad.png", "scale" : "2x" },
    { "size" : "29x29", "idiom" : "ipad", "filename" : "icon-29@1x-ipad.png", "scale" : "1x" },
    { "size" : "29x29", "idiom" : "ipad", "filename" : "icon-29@2x-ipad.png", "scale" : "2x" },
    { "size" : "40x40", "idiom" : "ipad", "filename" : "icon-40@1x-ipad.png", "scale" : "1x" },
    { "size" : "40x40", "idiom" : "ipad", "filename" : "icon-40@2x-ipad.png", "scale" : "2x" },
    { "size" : "76x76", "idiom" : "ipad", "filename" : "icon-76@1x-ipad.png", "scale" : "1x" },
    { "size" : "76x76", "idiom" : "ipad", "filename" : "icon-76@2x-ipad.png", "scale" : "2x" },
    { "size" : "83.5x83.5", "idiom" : "ipad", "filename" : "icon-83.5@2x-ipad.png", "scale" : "2x" },
    { "size" : "1024x1024", "idiom" : "ios-marketing", "filename" : "icon-1024.png", "scale" : "1x" }
  ],
  "info" : {
    "author" : "wizardry",
    "version" : 1
  }
}
JSON
