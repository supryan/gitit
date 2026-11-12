#!/bin/sh
# Assembles the Chrome extension in "chrome/build/GitIt for Chrome": the shared popup,
# dashboard, theme and icons from shared/, plus Chrome's own manifest and background
# script. The GitIt app bundles this folder (app/Makefile runs this first), and Settings'
# Install puts it where Chrome can load it; `make chrome` uses it straight from here.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
out="$here/build/GitIt for Chrome"

rm -rf "$out"
mkdir -p "$out"
# Everything in shared/ except hidden files and folders (.DS_Store, tools' marker folders)
# and its README.
rsync -a --exclude='.*' --exclude='README.md' "$here/../shared/" "$out/"
cp "$here/manifest.json" "$here/background.js" "$out/"
cp "$here"/icons/*.png "$out/icons/" # the toolbar icons, without the dot
echo "Built $out"
