#!/bin/bash
# Builds NVRMFB.kext from the NullMoth driver at release 2.9 with the HiDPI patch applied.
#
#   ./build.sh [work-dir]          default work dir: ./build
#
# Needs the Xcode Command Line Tools (xcode-select --install), git and curl.
# Output: <work-dir>/out/NVRMFB.kext
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=${1:-"$HERE/build"}
UPSTREAM=https://github.com/nullmoth/nvidia-macos-driver
BASE=7412cdd
OGKM_TAG=620.70.06
PATCH="$HERE/0001-NVRMFB-publish-HiDPI-modes-with-large-BAR1.patch"

mkdir -p "$WORK"
cd "$WORK"

echo "==> NullMoth driver @ $BASE"
[ -d nvidia-macos-driver ] || git clone -q "$UPSTREAM" nvidia-macos-driver
git -C nvidia-macos-driver checkout -q "$BASE"

echo "==> NVIDIA open-gpu-kernel-modules $OGKM_TAG (headers only)"
OGKM="$WORK/open-gpu-kernel-modules-$OGKM_TAG"
if [ ! -d "$OGKM" ]; then
  curl -sL "https://codeload.github.com/NVIDIA/open-gpu-kernel-modules/tar.gz/refs/tags/$OGKM_TAG" | tar -xz
  # The driver's own patch chain, in file-name order, as kexts/NVRM/patches/README.md describes
  P=nvidia-macos-driver/kexts/NVRM/patches
  for p in $(cd "$P" && ls *.patch | sort); do
    case $p in
      610-display-completion.patch|610-fsp-timer-double-destroy.patch) d="$OGKM" ;;
      *) d="$OGKM/src/nvidia-modeset" ;;
    esac
    patch -s --fuzz=0 -p1 -N -d "$d" < "$P/$p"
  done
fi

echo "==> applying the HiDPI patch"
git -C nvidia-macos-driver checkout -q -- kexts/NVRMFB/fb/nvrm-fb.cpp
git -C nvidia-macos-driver apply "$PATCH"

echo "==> building NVRMFB"
cd nvidia-macos-driver
OGKM="$OGKM" MINVER=26.0 bash build/fb_build.sh kexts "$WORK/out"
echo "done: $WORK/out/NVRMFB.kext"
