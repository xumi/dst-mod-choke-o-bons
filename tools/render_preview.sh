#!/bin/sh
# Regenerates art/preview.png (Workshop preview image) from the source drawing.
# Needs ImageMagick 6 and macOS's qlmanage. Run it only when the art changes.
set -e
cd "$(dirname "$0")/.."

TMP=$(mktemp -d)
sed 's|<g filter|<rect width="512" height="512" fill="#00ff00"/><g filter|' art/source/chokeobon.svg > "$TMP/key.svg"
qlmanage -t -s 1024 -o "$TMP" "$TMP/key.svg" >/dev/null 2>&1
convert "$TMP/key.svg.png" -fuzz 8% -fill none -draw "color 2,2 floodfill" -trim +repage \
    -resize x400 -background "#cdbf94" -gravity center -extent 512x512 \
    -alpha remove -alpha off -strip -define png:color-type=2 PNG24:art/preview.png
# The Mod Uploader wants a square image no bigger than 512x512 and looks for preview.jpg by default
convert art/preview.png -strip -quality 90 -sampling-factor 4:4:4 -interlace none art/preview.jpg
rm -rf "$TMP"
echo "Wrote art/preview.png and art/preview.jpg"
