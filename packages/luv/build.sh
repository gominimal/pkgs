#!/bin/bash
set -euo pipefail

# Reproducibility flags (see AGENTS.md).
export CFLAGS="${CFLAGS:-} -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export LDFLAGS="${LDFLAGS:-} -Wl,--build-id=none"

# Same configuration neovim's cmake.deps uses, except built as a shared
# library against the registry's shared libuv and luajit.
cmake -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DLUA_BUILD_TYPE=System \
  -DWITH_LUA_ENGINE=LuaJIT \
  -DWITH_SHARED_LIBUV=ON \
  -DBUILD_MODULE=OFF \
  -DBUILD_SHARED_LIBS=ON \
  -DLUA_COMPAT53_DIR="$(pwd)/lua-compat-5.3-$MINIMAL_ARG_COMPAT53_VERSION"
cmake --build build -j"$(nproc)"
DESTDIR="$OUTPUT_DIR" cmake --install build
