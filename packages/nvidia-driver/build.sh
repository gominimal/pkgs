#!/bin/bash
set -euo pipefail

VERSION="$MINIMAL_ARG_VERSION"
RUN_FILE="NVIDIA-Linux-x86_64-${VERSION}-no-compat32.run"

chmod +x "$RUN_FILE"
sh "$RUN_FILE" --extract-only --target nvidia-unpacked
cd nvidia-unpacked

DEST="$OUTPUT_DIR"
mkdir -p "$DEST/usr/lib" "$DEST/usr/bin" "$DEST/usr/lib/firmware/nvidia/${VERSION}"

install_lib_with_symlinks() {
  local src="$1"
  local soname="$2"
  cp -a "$src" "$DEST/usr/lib/"
  ln -sf "$(basename "$src")" "$DEST/usr/lib/${soname}"
  local unversioned="${soname%.*}"
  ln -sf "${soname}" "$DEST/usr/lib/${unversioned}"
}

install_lib_with_symlinks "libcuda.so.${VERSION}"                 "libcuda.so.1"
install_lib_with_symlinks "libnvidia-ml.so.${VERSION}"            "libnvidia-ml.so.1"
install_lib_with_symlinks "libnvidia-ptxjitcompiler.so.${VERSION}" "libnvidia-ptxjitcompiler.so.1"
install_lib_with_symlinks "libnvidia-nvvm.so.${VERSION}"          "libnvidia-nvvm.so.4"
install_lib_with_symlinks "libcudadebugger.so.${VERSION}"         "libcudadebugger.so.1"

cp -a "libnvidia-gpucomp.so.${VERSION}" "$DEST/usr/lib/" 2>/dev/null || true
cp -a "libnvidia-sandboxutils.so.${VERSION}" "$DEST/usr/lib/" 2>/dev/null || true
cp -a "libnvidia-tileiras.so.${VERSION}" "$DEST/usr/lib/" 2>/dev/null || true
cp -a libnvidia-nvvm70.so.4 "$DEST/usr/lib/" 2>/dev/null || true

for bin in nvidia-smi nvidia-debugdump nvidia-persistenced nvidia-cuda-mps-control nvidia-cuda-mps-server; do
  if [ -f "$bin" ]; then
    cp -a "$bin" "$DEST/usr/bin/"
    chmod 755 "$DEST/usr/bin/$bin"
  fi
done

if [ -f nvidia-modprobe ]; then
  cp -a nvidia-modprobe "$DEST/usr/bin/"
  chmod 4755 "$DEST/usr/bin/nvidia-modprobe" || chmod 755 "$DEST/usr/bin/nvidia-modprobe"
fi

cp -a firmware/gsp_ga10x.bin "$DEST/usr/lib/firmware/nvidia/${VERSION}/"
cp -a firmware/gsp_tu10x.bin "$DEST/usr/lib/firmware/nvidia/${VERSION}/"
