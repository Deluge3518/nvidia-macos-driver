#!/bin/bash
# fb_build.sh <src> <out>: build NVRMFB.kext (the IOFramebuffer) from kexts/NVRMFB into <out>/NVRMFB.kext.
# One translation unit, like accel_build.sh; it needs the OGKM modeset headers (nvkms.h, nvkms-kapi.h) but not the
# RM compile commands. It calls NVRM only through the nvkms-kapi functions table it reads from the IORegistry
# provider, so nothing from NVRM.kext is linked in.
set -uo pipefail
SRC=$1; OUT=$2; mkdir -p "$OUT/NVRMFB.kext/Contents/MacOS"
OGKM=${OGKM:-$HOME/ogkm610}
SDK=$(xcrun --show-sdk-path); KHDR="$SDK/System/Library/Frameworks/Kernel.framework/Headers"; KMS="$OGKM/src/nvidia-modeset"
# the same include set the modeset kext itself compiles with (utils.mk/os-interface), narrowed to what fb/nvrm-fb.cpp uses
CFLAGS=( -arch x86_64 -fapple-kext -mkernel -nostdinc -I"$KHDR" -I"$SRC" -I"$SRC/fb"
  -I"$KMS/os-interface/include" -I"$KMS/kapi/interface" -I"$KMS/kapi/include" -I"$KMS/include" -I"$KMS/interface"
  -I"$OGKM/src/common/sdk/nvidia/inc" -I"$OGKM/src/common/inc" -I"$OGKM/src/common/shared/inc"
  -DKERNEL -DKERNEL_PRIVATE -DDRIVER_PRIVATE -DAPPLE -DNeXT
  -std=c++17 -fno-rtti -fno-exceptions -fno-builtin -fno-common
  -Wall -Wno-unused-parameter -Wno-inconsistent-missing-override -Wno-unused-function -O2 )
xcrun clang++ "${CFLAGS[@]}" -c "$SRC/fb/nvrm-fb.cpp" -o "$OUT/nvrm-fb.o" 2>"$OUT/fb.err" || { grep error "$OUT/fb.err" | head; exit 1; }
xcrun clang++ -arch x86_64 -fapple-kext -nostdlib -Xlinker -kext -lkmodc++ -lkmod -lcc_kext "$OUT/nvrm-fb.o" -o "$OUT/NVRMFB.kext/Contents/MacOS/NVRMFB" 2>"$OUT/fbld.err" || { cat "$OUT/fbld.err" | head; exit 1; }
cp "$SRC/fb/Info.plist" "$OUT/NVRMFB.kext/Contents/Info.plist"
echo "NVRMFB $(md5 -q "$OUT/NVRMFB.kext/Contents/MacOS/NVRMFB") $(stat -f %z "$OUT/NVRMFB.kext/Contents/MacOS/NVRMFB") B  ($(xcrun clang++ --version | head -1))"
