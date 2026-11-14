#!/bin/sh
# Regenerates art/preview.png (Workshop preview image) from the source drawing.
# Needs ImageMagick 6 and macOS's qlmanage. Run it only when the art changes.
set -e
cd "$(dirname "$0")/.."

TMP=$(mktemp -d)
sed 's|<g filter|<rect width="512" height="512" fill="#00ff00"/><g filter|' art/source/chokeobon.svg > "$TMP/key.svg"
qlmanage -t -s 1024 -o "$TMP" "$TMP/key.svg" >/dev/null 2>&1
convert "$TMP/key.svg.png" -fuzz 8% -fill none -draw "color 2,2 floodfill" -trim +repage \
    -resize x400 -background "#cdbf94" -gravity center -extent 512x512 art/preview.png
rm -rf "$TMP"
echo "Wrote art/preview.png"
