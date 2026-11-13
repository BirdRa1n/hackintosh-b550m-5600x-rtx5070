#!/bin/bash
# Puts back the NVRMFB.kext and auxiliary kernel collection saved by install-fix.sh.
# Run with: sudo bash restore.sh   Then restart.
set -euo pipefail
PATH=/usr/bin:/bin:/usr/sbin:/sbin
HERE=$(cd "$(dirname "$0")" && pwd)
BK="$HERE/backup-installed"
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
[ -d "$BK/NVRMFB.kext" ] && [ -f "$BK/AuxiliaryKernelExtensions.kc" ] || { echo "no backup in $BK"; exit 1; }
rm -rf /Library/Extensions/NVRMFB.kext
ditto "$BK/NVRMFB.kext" /Library/Extensions/NVRMFB.kext
chown -R root:wheel /Library/Extensions/NVRMFB.kext
cp -p "$BK/AuxiliaryKernelExtensions.kc" /Library/KernelCollections/AuxiliaryKernelExtensions.kc
echo "restored NVRMFB (md5 $(md5 -q /Library/Extensions/NVRMFB.kext/Contents/MacOS/NVRMFB)) and the kernel collection. Restart now."
