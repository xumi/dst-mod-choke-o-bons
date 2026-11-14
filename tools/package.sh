#!/bin/sh
# Builds dist/choke-o-bons/ (only the files the game needs) and copies the
# Workshop preview images (PNG and JPG, no alpha channel) to dist/. Plain file copies, runs anywhere.
set -e
cd "$(dirname "$0")/.."

OUT=dist/choke-o-bons
rm -rf dist
mkdir -p "$OUT"
cp -R modinfo.lua modmain.lua modicon.tex modicon.xml scripts images anim "$OUT"/
cp art/preview.png art/preview.jpg dist/

find dist -name .DS_Store -delete
echo "Mod folder: $OUT"
echo "Preview:    dist/preview.png"
