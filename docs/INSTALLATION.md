# Installation

This guide covers using the EFI in this repository on matching hardware. It is not a full Hackintosh tutorial: if
you are new to OpenCore, read the [Dortania OpenCore Install Guide](https://dortania.github.io/OpenCore-Install-Guide/)
first, in particular the [AMD Desktop (Zen)](https://dortania.github.io/OpenCore-Install-Guide/AMD/zen.html) chapter.

> [!WARNING]
> An EFI is specific to its hardware. Even on an ASRock B550M, a different BIOS version, a different Wi-Fi card or
> a different USB layout can need changes. Treat this EFI as a reference, not a drop-in.

## 1. What is in `EFI.zip`

```
EFI/
├── BOOT/BOOTx64.efi
└── OC/
    ├── OpenCore.efi            OpenCore 1.0.9 (DEBUG build)
    ├── config.plist
    ├── ACPI/                   SSDT-EC, SSDT-USBX, SSDT-PLUG-ALT, SSDT-ALIBFix, SSDT-USB-Reset
    ├── Drivers/                OpenRuntime, OpenCanopy, HfsPlus, apfs_aligned, ResetNvramEntry
    ├── Kexts/                  see the table below
    ├── Resources/              OpenCanopy theme
    └── Tools/NullMothSafe.efi  boot entry that starts macOS once without the NVIDIA driver
```

| Kext | Version | Purpose |
|---|---|---|
| Lilu | 1.7.3 | Patching framework |
| VirtualSMC + SMCSuperIO | 1.3.9 | SMC emulation, fan and sensor readings |
| WhateverGreen | 1.7.2 | Graphics fixes |
| RestrictEvents | 1.1.7 | `revpatch=sbvmm,cpuname`: update channel and CPU name |
| AMFIPass | 1.4.1 | Lets the system run with AMFI relaxed |
| NVMeFix | 1.1.4 | NVMe power management |
| USBToolBox + UTBDefault | 1.2.0 | USB mapping |
| RTL812xLucy | 1.1.302 | Realtek RTL8125B 2.5 GbE |
| itlwm | 2.3.0 | Intel Wi-Fi |
| IntelBluetoothFirmware, IntelBTPatcher, BlueToolFixup | 2.5.0 / 2.7.3 | Intel Bluetooth |
| IntelMKLFixup | 1.0.0 | Intel MKL on AMD CPUs |
| AppleMCEReporterDisabler | — | Required with the MacPro7,1 SMBIOS on AMD |
| CtlnaAHCIPort | — | SATA controller support |

The NVIDIA kexts (`NVRM`, `NVRMFB`, `NVAccel`, `NVRMAGDC`, `NMXAudio`) are **not** in the EFI. The NullMoth
installer puts them in `/Library/Extensions`.

## 2. What was changed for publishing

| Item | Original | In `EFI.zip` |
|---|---|---|
| `PlatformInfo > Generic > SystemSerialNumber` | the machine's own | `W00000000001` (placeholder) |
| `PlatformInfo > Generic > MLB` | the machine's own | `M0000000000000001` (placeholder) |
| `PlatformInfo > Generic > SystemUUID` | the machine's own | `00000000-0000-0000-0000-000000000000` |
| `PlatformInfo > Generic > ROM` | the machine's MAC | `000000000000` |
| `boot-args` | included `nvfblog=1` | removed (verbose framebuffer log, only needed for debugging) |
| `Misc > Debug > Target` | `67` (logs to a file on every boot) | `3` (no log files written to the EFI partition) |
| NVRAM Bluetooth controller entries | present | removed (machine specific) |
| `config.plist.*` backups | 10 files | removed |

## 3. Generate your own SMBIOS (required)

The placeholders boot, but iServices (iMessage, FaceTime, App Store sign-in) need unique values.

1. Get [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) (or `macserial` from the OpenCore package).
2. Generate values for **`MacPro7,1`**.
3. In `EFI/OC/config.plist`, under `PlatformInfo > Generic`, set:
   - `SystemSerialNumber` ← Serial
   - `MLB` ← Board Serial
   - `SystemUUID` ← SmUUID
   - `ROM` ← your Ethernet MAC address (6 bytes, without separators)
4. Check that the serial is **not** valid on [Apple's coverage page](https://checkcoverage.apple.com/). "Invalid
   serial" is what you want.

Never publish your own values. If you share your EFI, replace them with placeholders first.

## 4. BIOS

| Setting | Value | Source |
|---|---|---|
| Above 4G Decoding | Enabled | Observed: the GPU's BAR1 is mapped above 4 GB |
| Resizable BAR (Re-Size BAR Support) | Enabled | Observed: the driver reports an 8 GB BAR1 |
| CSM | Disabled | Dortania recommendation |
| Secure Boot | Disabled | Dortania recommendation |

For everything else, follow Dortania's AMD BIOS section. On a Ryzen 5 5600X, **Precision Boost Overdrive** and a
correct **EXPO/XMP** memory profile are worth checking: the Metal-to-Vulkan translation runs largely on the CPU,
see [PERFORMANCE.md](PERFORMANCE.md).

## 5. boot-args

```
debug=0x100 keepsyms=1 -ibtcompatbeta revpatch=sbvmm,cpuname nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth
amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0 gfxrst=4 nvfbhidpi=1
```

| Argument | Purpose |
|---|---|
| `debug=0x100 keepsyms=1` | Keep the machine on screen after a panic, with symbols in the log |
| `-ibtcompatbeta` | Intel Bluetooth on newer macOS |
| `revpatch=sbvmm,cpuname` | RestrictEvents: OS updates and CPU name in About This Mac |
| `nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth` | NullMoth driver: framebuffer, acceleration, up to 4 heads |
| `amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0` | Relaxed AMFI, needed by the driver's Metal plugin |
| `gfxrst=4` | Boot graphics handoff |
| `nvfbhidpi=1` | NullMoth: back HiDPI modes with a desktop up to twice the panel size |

`boot-args` is in `NVRAM > Delete`, so OpenCore rewrites it from `config.plist` on every boot. A value set with
`sudo nvram boot-args=...` does not survive a restart: edit `config.plist` instead.

## 6. SIP

`csr-active-config` is `0x0A43` (kext signing, filesystem protections and NVRAM protections off). This is what the
NullMoth installer requires. Authenticated Root is disabled as well.

## 7. NVIDIA driver

1. Install the latest release of the [NullMoth driver](https://github.com/nullmoth/nvidia-macos-driver) with its
   1401 app.
2. In 1401 › Tools, turn on **HiDPI (Retina) modes**. This adds `nvfbhidpi=1` to the boot-args in `config.plist`.
3. Restart.

If the screen stays black after a driver change, choose **1401: Start once without NVIDIA driver** in the OpenCore
picker.

## 8. HiDPI on an ultrawide

See [HIDPI.md](HIDPI.md). Short version:

```bash
sudo ./hidpi/install-override.sh     # then restart
```

Choose a HiDPI resolution in System Settings › Displays or in BetterDisplay.
