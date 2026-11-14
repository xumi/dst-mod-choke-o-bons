#!/bin/sh
# Builds dist/choke-o-bons/ (only the files the game needs) and dist/preview.png
# (Workshop preview image). Needs ImageMagick 6 and macOS's qlmanage.
set -e
cd "$(dirname "$0")/.."

OUT=dist/choke-o-bons
rm -rf dist
mkdir -p "$OUT"
cp -R modinfo.lua modmain.lua modicon.tex modicon.xml scripts images anim "$OUT"/

TMP=$(mktemp -d)
sed 's|<g filter|<rect width="512" height="512" fill="#00ff00"/><g filter|' art/source/chokeobon.svg > "$TMP/key.svg"
qlmanage -t -s 1024 -o "$TMP" "$TMP/key.svg" >/dev/null 2>&1
convert "$TMP/key.svg.png" -fuzz 8% -fill none -draw "color 2,2 floodfill" -trim +repage \
    -resize x400 -background "#cdbf94" -gravity center -extent 512x512 dist/preview.png
rm -rf "$TMP"
find dist -name .DS_Store -delete
echo "Mod folder: $OUT"
echo "Preview:    dist/preview.png"
