#!/usr/bin/env bash
# Render icon/tine.svg into AppIcon.icns for the app bundle.
# Requires: rsvg-convert (brew install librsvg), iconutil + sips (built in).
set -euo pipefail
cd "$(dirname "$0")"

SVG="tine.svg"
ICONSET="$(mktemp -d)/AppIcon.iconset"
OUT="AppIcon.icns"
mkdir -p "$ICONSET"

emit() { # emit <name> <pixels>
  rsvg-convert -w "$2" -h "$2" "$SVG" -o "$ICONSET/$1"
}

emit icon_16x16.png       16
emit icon_16x16@2x.png    32
emit icon_32x32.png       32
emit icon_32x32@2x.png    64
emit icon_128x128.png     128
emit icon_128x128@2x.png  256
emit icon_256x256.png     256
emit icon_256x256@2x.png  512
emit icon_512x512.png     512
emit icon_512x512@2x.png  1024

iconutil -c icns "$ICONSET" -o "$OUT"
rm -rf "$(dirname "$ICONSET")"
echo "✅ $OUT ($(du -h "$OUT" | cut -f1))"
