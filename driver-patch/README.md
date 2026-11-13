# NVRMFB patch: HiDPI modes with a large BAR1

A two-part change to the framebuffer kext of the
[NullMoth NVIDIA driver for macOS](https://github.com/nullmoth/nvidia-macos-driver), release **2.9**
(commit `7412cdd`). On this machine it was part of what made HiDPI resolutions selectable; see
[docs/HIDPI.md](../docs/HIDPI.md) for the investigation.

> [!CAUTION]
> This is an **unofficial, experimental** patch, tested on one machine. Use the official NullMoth releases
> whenever possible: they get fixes and hardware support this patch does not. Installing a driver update through
> the 1401 app replaces the patched kext.

## What it changes

File: `kexts/NVRMFB/fb/nvrm-fb.cpp`, 28 lines added, nothing removed.

1. **`IOFBMemorySize` is never published as 0.** `getVRAMRange()` returns the whole BAR1, 8 GB with Resizable BAR on
   an RTX 5070, and a later 32-bit write of that length leaves 0. The existing `setProperty` override now catches
   every write of `IOFBMemorySize` and replaces zero, or any value above the cap, with 2047 MB. The first 8 writes
   are logged as `IOFBMemorySize write <value> (<bits> bits) -> <published>`.
2. **The system aperture covers the whole scanout allocation**, not only the current mode's surface. With
   `nvfbhidpi=1` the driver already allocates enough for a desktop twice the panel size; the aperture now reports
   that allocation, which belongs to this framebuffer alone.

## Files

| File | Purpose |
|---|---|
| `0001-NVRMFB-publish-HiDPI-modes-with-large-BAR1.patch` | The change, against upstream `7412cdd` |
| `build.sh` | Clones upstream at `7412cdd`, fetches NVIDIA's headers, applies the driver's own patch chain and this patch, builds `NVRMFB.kext` |
| `install-fix.sh` | Backs up the installed kext and kernel collection, swaps the binary, rebuilds the auxiliary kernel collection |
| `restore.sh` | Puts the backed-up kext and kernel collection back |
| `LICENSE` | PolyForm Noncommercial 1.0.0, the driver's licence, which applies to this patch |

## Requirements

- macOS 26 with the NullMoth driver **2.9** installed (the patch targets that release)
- Xcode Command Line Tools: `xcode-select --install`
- `boot-args` containing `nvfbhidpi=1`

## Build

```bash
./build.sh            # output: build/out/NVRMFB.kext
```

The build is reproducible: the stock source built this way gives the same binary as the NVRMFB in the official 2.9
package, and the patched build gives MD5 `eeac80c01dc7ab6b1b6786b31231f7bb`, the binary tested on this machine.

## Install

```bash
sudo ./install-fix.sh
```

Then restart. Check it is active:

```bash
md5 -q /Library/Extensions/NVRMFB.kext/Contents/MacOS/NVRMFB          # eeac80c0...
ioreg -l -w0 | grep '"IOFBMemorySize"'                                # 2146435072, not 0
log show --last boot --predicate 'eventMessage CONTAINS "IOFBMemorySize write"' --style compact
```

## Roll back

```bash
sudo ./restore.sh
```

Then restart. If the machine does not reach the desktop, choose **1401: Start once without NVIDIA driver** in the
OpenCore picker, run `restore.sh`, and restart.

## Licence

This patch modifies software licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE) and is distributed
under the same terms, for noncommercial use only.

```
Required Notice: Copyright (c) 2026 NullMoth Systems (https://nullmothsystems.com)
```
