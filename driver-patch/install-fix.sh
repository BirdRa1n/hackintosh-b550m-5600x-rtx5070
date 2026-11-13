#!/bin/bash
# Replaces the installed NVRMFB binary with a patched build and rebuilds the auxiliary kernel
# collection, the same way the NullMoth installer (package/install.sh) does.
#
#   sudo ./install-fix.sh [path/to/NVRMFB.kext]     default: ./build/out/NVRMFB.kext
#
# The first run saves the original NVRMFB.kext and kernel collection to ./backup-installed;
# restore.sh puts them back. Restart after it finishes.
set -euo pipefail
PATH=/usr/bin:/bin:/usr/sbin:/sbin
HERE=$(cd "$(dirname "$0")" && pwd)
KEXT=${1:-"$HERE/build/out/NVRMFB.kext"}
NEW="$KEXT/Contents/MacOS/NVRMFB"
EXT=/Library/Extensions
KC=/Library/KernelCollections/AuxiliaryKernelExtensions.kc
BK="$HERE/backup-installed"

[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
[ -f "$NEW" ] || { echo "missing $NEW (run ./build.sh first)"; exit 1; }
[ -d "$EXT/NVRMFB.kext" ] || { echo "NVRMFB.kext is not installed; install the NullMoth driver first"; exit 1; }

if [ ! -d "$BK/NVRMFB.kext" ]; then
  mkdir -p "$BK"
  ditto "$EXT/NVRMFB.kext" "$BK/NVRMFB.kext"
  cp -p "$KC" "$BK/AuxiliaryKernelExtensions.kc"
  echo "backup: $BK"
else
  echo "backup already present: $BK (kept)"
fi

# Only the binary changes; the installed Info.plist (the packaged one) is kept.
cp "$NEW" "$EXT/NVRMFB.kext/Contents/MacOS/NVRMFB"
chown -R root:wheel "$EXT/NVRMFB.kext" && chmod -R go-w "$EXT/NVRMFB.kext"
echo "installed binary md5: $(md5 -q "$EXT/NVRMFB.kext/Contents/MacOS/NVRMFB")"

KARG=(--allow-missing-kdk); [ -f /System/Library/Kernels/kernel ] && KARG+=(--kernel /System/Library/Kernels/kernel)
NEWKC="$KC.nvrmfb-fix-new"; rm -f "$NEWKC"
kmutil create -n aux --volume-root / "${KARG[@]}" \
  -B /System/Library/KernelCollections/BootKernelExtensions.kc \
  -S /System/Library/KernelCollections/SystemKernelExtensions.kc \
  --repository "$EXT" -A "$NEWKC" -z >"$HERE/kmutil.log" 2>&1 \
  || { tail -20 "$HERE/kmutil.log"; echo "kmutil failed; nothing published. Run restore.sh"; exit 1; }
INS=$(kmutil inspect -a x86_64 -A "$NEWKC")
for k in NVRM NVAccel NVRMFB NVRMAGDC; do
  printf '%s\n' "$INS" | grep -q "com.nullmoth.$k" \
    || { echo "com.nullmoth.$k missing from the new collection; not published. Run restore.sh"; rm -f "$NEWKC"; exit 1; }
done
mv -f "$NEWKC" "$KC"
echo "OK: new auxiliary kernel collection published. Restart now."
