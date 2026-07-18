#!/bin/sh
# ComfyConnect VPN — brand asset generator
# Usage: branding/generate_brand_assets.sh <master-logo.svg|png>
# Requires ImageMagick 7 (`magick`).  On macOS: brew install imagemagick
#
# Regenerates every brand-carrying Windows GUI icon/bitmap from one square master logo,
# and the web-console favicon. Filenames and sizes match what the resource compiler expects.
set -e

SRC="$1"
if [ -z "$SRC" ] || [ ! -f "$SRC" ]; then
  echo "Usage: $0 <master-logo.svg|png>   (square, transparent background)"
  exit 1
fi
if ! command -v magick >/dev/null 2>&1; then
  echo "ERROR: ImageMagick 'magick' not found. Install it first (brew/choco install imagemagick)."
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICO_SIZES="16,32,48,256"

make_ico() {   # $1 = destination .ico path
  magick "$SRC" -background none -define icon:auto-resize="$ICO_SIZES" "$1"
  echo "  wrote $1"
}

echo "Generating .ico app icons..."
for dst in \
  "$ROOT/src/vpnsmgr/vpnsmgr.ico" \
  "$ROOT/src/vpnsmgr/VPNSvr.ico" \
  "$ROOT/src/vpncmgr/VPN.ico" \
  "$ROOT/src/vpncmgr/Server.ico" \
  "$ROOT/src/vpncmgr/Server_Offline.ico" \
  "$ROOT/src/PenCore/VPN.ico" \
  "$ROOT/src/PenCore/VPNSvr.ico" \
  "$ROOT/src/PenCore/Setup.ico" \
  "$ROOT/src/PenCore/EasyInstaller.ico" ; do
  make_ico "$dst"
done

echo "Generating 49x49 logo bitmap..."
magick "$SRC" -background white -alpha remove -resize 49x49^ -gravity center -extent 49x49 \
  -type Palette BMP3:"$ROOT/src/PenCore/SELOGO49x49.bmp"
echo "  wrote src/PenCore/SELOGO49x49.bmp"

echo "Generating web favicon..."
magick "$SRC" -background none -resize 64x64 "$ROOT/src/bin/hamcore/wwwroot/admin/default/favicon.png"
echo "  wrote wwwroot/admin/default/favicon.png"

echo "Done. Rebuild the Windows GUI to embed the new icons."
