#!/bin/bash
# Installs the HiDPI display override for the 3440x1440 monitor (vendor 0x216d, product 0x3400).
#
#   sudo ./install-override.sh            install
#   sudo ./install-override.sh --remove   remove
#
# Restart (or reconnect the display) afterwards. For another monitor, see docs/HIDPI.md.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
DIR=/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-216d
FILE=DisplayProductID-3400

[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
if [ "${1:-}" = --remove ]; then
  rm -f "$DIR/$FILE" && echo "removed $DIR/$FILE"
  exit 0
fi
plutil -lint "$HERE/$FILE" >/dev/null
mkdir -p "$DIR"
cp "$HERE/$FILE" "$DIR/$FILE"
chown -R root:wheel /Library/Displays
echo "installed $DIR/$FILE - restart to apply"
