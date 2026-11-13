# HiDPI display override

Adds HiDPI ("looks like") resolutions for a 3440×1440 display with vendor ID `0x216d` and product ID `0x3400`.

| Looks like | Rendered at |
|---|---|
| 3440×1440 | 6880×2880 |
| 3008×1260 | 6016×2520 |
| 2752×1152 | 5504×2304 |
| 2560×1072 | 5120×2144 |
| 2048×858 | 4096×1716 |
| 1720×720 | 3440×1440 |

Each entry ends in `00000001 00800000` (`kDisplayModeValidForHiResFlag`). The `00200000` suffix found in many
guides marks modes as mirror-only, and macOS hides them. See [docs/HIDPI.md](../docs/HIDPI.md#step-6--the-overrides-flag-word).

## Install

```bash
sudo ./install-override.sh            # restart afterwards
sudo ./install-override.sh --remove   # undo
```

Requires `nvfbhidpi=1` in the boot-args. For a different monitor, follow
[Using it on another monitor](../docs/HIDPI.md#using-it-on-another-monitor).

## Tools

```bash
osascript -l JavaScript tools/list-modes.js   # current mode + public mode list
zsh tools/dmflags.sh                          # size and flags of every mode macOS stored
```
