#!/bin/zsh
# Prints width x height and flags of every IODisplayModeInformation (DM) macOS stored in IOFBConfig
le() { local h=$1; echo $((16#${h[7,8]}${h[5,6]}${h[3,4]}${h[1,2]})); }
ioreg -l -w0 -r -c NVRMNVDAFramebuffer | grep -o '"IOFBConfig" = .*' | head -1 | grep -oE '"DM"=<[0-9a-f]{40}' | cut -c7- | sort -u | while read dm; do
  printf "%5sx%-5s flags=0x%08x\n" $(le ${dm[1,8]}) $(le ${dm[9,16]}) $(le ${dm[33,40]})
done | sort -u | sort -t x -k1 -n
