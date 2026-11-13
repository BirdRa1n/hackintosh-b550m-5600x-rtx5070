# HiDPI on a 3440×1440 ultrawide

How this build got sharp HiDPI ("looks like") resolutions on a 34" 3440×1440 165 Hz display with an RTX 5070 and the
NullMoth driver. Each step lists what was observed and how, so the same checks can be repeated on another machine.

## The problem

Choosing a smaller resolution in System Settings or BetterDisplay made everything blurry. macOS was **stretching**
a low-resolution desktop onto the panel instead of rendering a **2× desktop and scaling it down**, which is what
HiDPI does.

| Mode | Desktop rendered | Shown on the panel | Result |
|---|---|---|---|
| 2752×1152 (stretched) | 2752×1152 | upscaled to 3440×1440 | soft, blurry |
| 2752×1152 **HiDPI** | 5504×2304 | downscaled to 3440×1440 | sharp |

The panel always shows 3440×1440 physical pixels. HiDPI changes the size of the interface and how cleanly it is
rendered, not the number of physical pixels.

## Step 1 — the driver side was already enabled

The 1401 app's **HiDPI (Retina) modes** button had added `nvfbhidpi=1` to the boot-args, and the kernel log confirms
the driver read it:

```
NVRM-fb: nvfbhidpi: scaled desktops up to 6880x2880 on a 3440x1440 raster
NVRM-fb: fbmodes: boot raster 3440x1440 pitch 13824; scanout allocation sized for 6880x2880 (77760 KB, boot needs 19456 KB)
```

Yet the mode list had no mode whose backing size was larger than its point size.

## Step 2 — macOS needs a display override

A 34" 3440×1440 panel is about 110 PPI. macOS does not create HiDPI modes for such a display unless an override in
`/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-<vid>/DisplayProductID-<pid>` lists them under
`scale-resolutions`. This machine had no override at all.

The vendor and product IDs come from the registry:

```bash
ioreg -l -w0 | grep -E '"DisplayVendorID"|"DisplayProductID"'
# DisplayVendorID = 8557  (0x216d)   DisplayProductID = 13312  (0x3400)
```

Each `scale-resolutions` entry is 16 bytes, big-endian: backing width, backing height, and two flag words. A HiDPI
"looks like" size W×H is listed as its 2× backing size:

| Looks like | Backing entry |
|---|---|
| 3440×1440 | 6880×2880 |
| 3008×1260 | 6016×2520 |
| 2752×1152 | 5504×2304 |
| 2560×1072 | 5120×2144 |
| 2048×858 | 4096×1716 |
| 1720×720 | 3440×1440 |

## Step 3 — the driver accepted the modes, WindowServer did not list them

With the override installed and the boot-arg `nvfblog=1` (verbose framebuffer log), the driver validated every HiDPI
timing at every refresh rate:

```
validateDetailedTiming ... 3440x1440 desktop 6880x2880 rotation 0x0 pclk 879710000 -> OK
validateDetailedTiming ... 3440x1440 desktop 5504x2304 rotation 0x0 pclk 879710000 -> OK
```

installed them, and WindowServer queried each one:

```
dt 0x8000100a raster 3440x1440 desktop 6880x2880 rotation 0x0 pclk 639790000
getPixelInformation 0x8000100a ap 0 -> 6880x2880 bytesPerRow 27648
```

Still, none reached the mode list. The kernel side was working, and the filtering happened later.

## Step 4 — `IOFBMemorySize` was 0

The driver sets `IOFBMemorySize` to 8 GB in `start()`, yet the registry showed 0:

```bash
ioreg -l -w0 -r -c NVRMNVDAFramebuffer | grep '"IOFBMemorySize"'
#   "IOFBMemorySize" = 0
```

`getVRAMRange()` returns the whole BAR1, which is **8 GB** (`0x200000000`) with Resizable BAR on this card. Logging
every write of the property showed a later write of that length as a 32-bit number, which keeps only the low 32 bits:

```
NVRM-fb: fb0: IOFBMemorySize write 8589934592 (64 bits) -> 2146435072
NVRM-fb: fb0: IOFBMemorySize write 0 (32 bits) -> 2146435072
```

Any BAR1 of 4 GB or more truncates to 0. The patch intercepts these writes and publishes just under 2 GB instead,
a value that reads the same as a signed or unsigned 32-bit or a 64-bit number.

## Step 5 — the aperture covered only the boot surface

`getApertureRange()` reported the current mode's surface plus 128 bytes: 19,906,688 bytes at 3440×1440. Every mode
that appeared fit in that size, and every HiDPI mode (28 MB to 79 MB) did not. The patch reports the whole scanout
allocation that `nvfbhidpi=1` already reserves (79,626,240 bytes here). That allocation belongs to this framebuffer,
so the aperture still covers no other memory.

## Step 6 — the override's flag word

The stored mode information showed where the remaining filter was. Decoding the flags macOS recorded for each mode
([`hidpi/tools/dmflags.sh`](../hidpi/tools/dmflags.sh)):

| Override suffix | Flags stored for the HiDPI modes | Listed? |
|---|---|:---:|
| `00000001 00200000` (common in guides) | `0x00700003`, includes `kDisplayModeValidForMirroringFlag` | ❌ |
| `00000001 00a00000` | `0x00f00003`, HiRes **and** mirroring | ❌ |
| `00000001 00800000` | `0x00d00003`, `kDisplayModeValidForHiResFlag` only | ✅ |

The fourth word of each entry becomes the mode's flags. Every mode carrying `0x00200000` was hidden from the normal
list, including macOS's own 16:10 and 16:9 modes on this panel, so that bit marks a mode as mirror-only.
[`hidpi/DisplayProductID-3400`](../hidpi/DisplayProductID-3400) uses `00800000`.

## Result

```
Current mode: looks like 2752x1152, backing 5504x2304 @ 165 Hz
```

HiDPI modes from 1720×720 to 3440×1440 are selectable in BetterDisplay, sharp, at the panel's full 165 Hz.

> [!NOTE]
> `CGDisplayCopyAllDisplayModes`, the public API that `hidpi/tools/list-modes.js` uses, does **not** return these
> HiDPI modes even while one is active. BetterDisplay uses a different path and lists them. Check the **current**
> mode (the "Current:" line of the script's output), not the list, to confirm HiDPI is working.

### What is not known

The driver patch and the corrected override were tested **together**. Steps 4 and 5 fixed real problems, but the
HiDPI modes only became selectable after step 6, so the override alone may be sufficient on the stock driver. To
find out, run `sudo ./driver-patch/restore.sh`, restart, and check whether BetterDisplay still offers HiDPI modes.

## Cost

A HiDPI desktop is rendered at up to 4× the pixel count of the native mode, and on this driver every frame goes
through the Metal-to-Vulkan translation:

| Mode | Pixels per frame | vs native |
|---|---|---|
| 3440×1440 native | 4.95 M | 1× |
| 2752×1152 HiDPI | 12.7 M | 2.6× |
| 3440×1440 HiDPI | 19.8 M | 4× |

If the interface feels heavy, use 120 Hz instead of 165 Hz, or switch to native when HiDPI is not needed.

## Using it on another monitor

1. Find your IDs with the `ioreg` command above and convert them to lowercase hex.
2. Pick the "looks like" sizes you want, double them, and build each entry as
   `printf "%08x%08x0000000100800000" <2W> <2H> | xxd -r -p | base64`.
3. Save the plist as `DisplayVendorID-<vid>/DisplayProductID-<pid>` under the overrides folder, owned by
   `root:wheel`, and restart.
4. Keep `nvfbhidpi=1` in the boot-args so the driver reserves memory for desktops up to twice the panel size.

## Tools

| Script | What it shows |
|---|---|
| [`hidpi/tools/list-modes.js`](../hidpi/tools/list-modes.js) | `osascript -l JavaScript list-modes.js`: current mode and the public mode list |
| [`hidpi/tools/dmflags.sh`](../hidpi/tools/dmflags.sh) | `zsh dmflags.sh`: size and flags of every mode macOS stored for the framebuffer |
