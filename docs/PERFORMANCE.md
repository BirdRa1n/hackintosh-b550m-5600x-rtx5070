# Performance

Measurements taken on this build (macOS 26.7.3, NullMoth driver 2.9, display at 3440×1440 HiDPI 2752×1152,
165 Hz). They are quick checks meant to show where the time goes, not a benchmark suite.

## CPU

Effective clock measured with a dependent chain of integer adds (one add per cycle on Zen 3), so adds per second equal
the clock actually reached:

| Load | Measured | Ryzen 5 5600X spec |
|---|---|---|
| 1 thread | **≈ 4.45 GHz** | boost up to 4.6 GHz |
| 12 threads | **≈ 3.7 GHz** | base 3.7 GHz; ~4.2–4.4 GHz all-core is typical under Windows with PBO and good cooling |

The CPU boosts normally on single-threaded work. All-core clocks sit at base, which leaves some headroom that the
BIOS (Precision Boost Overdrive, cooling) may recover.

## GPU

A Metal compute benchmark run directly on the card:

```
device: NVIDIA GeForce RTX 5070 (NVMTL over NVIDIA GeForce RTX 5070 (NVK GB205-A))
```

| Test | Measured | RTX 5070 theoretical | Share |
|---|---|---|---|
| FP32 FMA throughput | **≈ 18 TFLOPS** (stable over 5 runs) | ≈ 31 TFLOPS | ≈ 58 % |
| Memory copy bandwidth | **≈ 590 GB/s** | ≈ 672 GB/s | ≈ 88 % |

- Memory bandwidth near peak means the card reaches its top performance state, so clocks are not capped.
- 58 % of peak FP32 on a synthetic FMA loop is reasonable for Mesa's open shader compiler (NAK), which this driver
  uses.
- The fans stay off at desktop load: the RTX 5070 stops them below roughly 50–60 °C.

## Where the slowness comes from

On this driver, macOS's Metal calls are translated to Vulkan (NVK) before they reach the GPU, and much of that work
runs on the **CPU**. WindowServer, macOS's window compositor, used 57–69 % of a CPU core in HiDPI at 165 Hz. The GPU
itself is fast; the translation in front of it is the limit.

### What helps

| Change | Effect |
|---|---|
| System Settings › Accessibility › Display › **Reduce transparency** | Removes the blur passes behind the menu bar, Dock and sidebars |
| **120 Hz** instead of 165 Hz | 27 % fewer frames for WindowServer to compose |
| **Native 3440×1440** when HiDPI is not needed | 2.6× fewer pixels per frame than 2752×1152 HiDPI |
| BIOS: **PBO**, **EXPO/XMP**, adequate cooling | Higher all-core CPU clocks for the translation layer |
| Keep the **NullMoth driver updated** | Almost every release brings translation and compositor improvements |

### What did not help

`NVRM_610_BOOST=hold` in `/Library/GPUBundles/nvmtl/nvrm610.conf` keeps the GPU at full clocks while any Metal
client is alive. It made no visible difference here, because the GPU was not the bottleneck, and it was reverted to
the default (boost per burst of work).
