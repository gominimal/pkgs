#!/bin/sh
set -ex

BUILD_ROOT="$PWD"

# build_odin.sh bakes ODIN_VERSION into the compiler. Without a .git directory
# it falls back to `date +%Y-%m`, which reads the wall clock and would make the
# build non-reproducible; pin it to the month of the release instead. Fail loudly
# if upstream stops stamping the version this way.
grep -q 'date +"%Y-%m"' build_odin.sh
sed -i "s|^\([[:space:]]*\)GIT_DATE=.*|\1GIT_DATE=\"${MINIMAL_ARG_VERSION_DATE}\"|" build_odin.sh

# sed exits 0 whether or not it matched anything, so the grep above only proves
# the wall-clock fallback still exists -- not that we neutralised it. If upstream
# renames GIT_DATE while keeping that fallback, the substitution silently does
# nothing and the build month gets baked into the binary: a non-reproducible
# package that passes every check until the month rolls over. Assert the pin.
grep -q "GIT_DATE=\"${MINIMAL_ARG_VERSION_DATE}\"" build_odin.sh

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac

export CXX=clang++
export LLVM_CONFIG=llvm-config
export CPPFLAGS="-ffile-prefix-map=$(pwd)=/builddir"
export CXXFLAGS="$MARCH -pipe -gno-record-gcc-switches"
export LDFLAGS="-Wl,--build-id=none"

# `release` compiles with -O3; `release-native` would add -march=native, which
# is not reproducible across builders.
./build_odin.sh release

ODIN_ROOT="$OUTPUT_DIR/usr/lib/odin"

install -D -m 0755 odin "$ODIN_ROOT/odin"
install -D -m 0644 LICENSE "$ODIN_ROOT/LICENSE"
cp -r base core vendor examples "$ODIN_ROOT/"

# --- vendor collection ------------------------------------------------------
# Upstream checks prebuilt libraries into vendor/. Everything we can build from
# source, we build; everything that cannot run on this platform, we drop. What
# remains prebuilt is called out explicitly at the bottom of this section.
VENDOR="$ODIN_ROOT/vendor"

case $(uname -m) in
  x86_64)  VENDOR_ARCH=linux-amd64; VENDOR_ARCH_OTHER=linux-arm64 ;;
  aarch64) VENDOR_ARCH=linux-arm64; VENDOR_ARCH_OTHER=linux-amd64 ;;
  # Without this, VENDOR_ARCH_OTHER would be empty and the rm below would take
  # out the whole box3d/lib directory rather than one arch's subdirectory.
  *)       echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

# Windows artifacts — upstream's own Linux release tarball drops these too
# (~140MB of .lib/.dll/.exe/.pdb).
sh ci/remove_windows_binaries.sh "$VENDOR"

# macOS artifacts: this package is Linux-only and cannot produce Mach-O.
find "$VENDOR" -type d -name darwin -prune -exec rm -rf {} +
rm -rf "$VENDOR/raylib/macos"
rm -f "$VENDOR"/box2d/lib/box2d_darwin_*.a

# The other Linux arch: we build per-arch, so it is dead weight.
rm -rf "$VENDOR/box3d/lib/$VENDOR_ARCH_OTHER"

# Reproducibility: the vendor Makefiles hardcode their own -O flags and never
# reference $(CFLAGS), so -ffile-prefix-map has to ride in on $(CC). stb and
# cgltf use assert(), which bakes __FILE__ into the objects without it.
VENDOR_CC="gcc -ffile-prefix-map=$VENDOR=/builddir"

# box3d, stb and cgltf ship their full C source in-tree, so these need no
# network access and no dependency beyond the C toolchain we already have.
# Upstream ships no Linux build of stb or cgltf at all — it expects users to run
# these same Makefiles by hand — so building them here is net-new coverage.
(
  cd "$VENDOR/box3d/src"
  rm -rf ../lib/linux-*
  # Upstream's build.sh calls `cc`, which the sandbox does not provide.
  $VENDOR_CC -c -O2 -std=c17 -fPIC -Iinclude src/*.c
  mkdir -p "../lib/$VENDOR_ARCH"
  ar -D rcs "../lib/$VENDOR_ARCH/libbox3d.a" ./*.o
  rm -f ./*.o
)
make -C "$VENDOR/stb/src"   CC="$VENDOR_CC" AR="ar -D" unix
make -C "$VENDOR/cgltf/src" CC="$VENDOR_CC" AR="ar -D" unix

# box2d ships bindings but no Linux library and no in-tree C source, so its
# tarball is a Source above rather than something we compile in place. Build it
# outside the vendor tree so no cmake scratch lands in the package output.
# On amd64 the bindings pick the AVX2 or SSE2 archive from the target's feature
# set at compile time, so both have to exist.
build_box2d() {
  rm -rf "$BUILD_ROOT/box2d-build"
  cmake -S "$BUILD_ROOT/box2d-$MINIMAL_ARG_BOX2D_VERSION" -B "$BUILD_ROOT/box2d-build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBOX2D_SAMPLES=OFF -DBOX2D_VALIDATE=OFF -DBOX2D_UNIT_TESTS=OFF \
    -DCMAKE_C_FLAGS="-ffile-prefix-map=$BUILD_ROOT=/builddir" \
    -DBOX2D_AVX2="$1"
  cmake --build "$BUILD_ROOT/box2d-build" -j"$(nproc)"
  cp "$BUILD_ROOT/box2d-build/src/libbox2d.a" "$VENDOR/box2d/lib/$2"
}
case "$VENDOR_ARCH" in
  linux-amd64)
    build_box2d ON  box2d_other_amd64_avx2.a
    build_box2d OFF box2d_other_amd64_sse2.a
    ;;
  linux-arm64)
    build_box2d OFF box2d_other.a
    ;;
esac
rm -rf "$BUILD_ROOT/box2d-build"

# lua: the libraries come from the lua51..lua54 packages. The bindings reach for
# a bundled library only on amd64 and fall back to `system:lua<ver>` elsewhere,
# so there is nothing to install for arm64 -- but the checked-in amd64 blobs are
# still dead weight there, hence the unconditional rm. The vendor filenames are
# upstream's and are not consistent (liblua5.1 but liblua52), so the series and
# the suffix are passed separately.
install_lua() { # $1 = series (5.1), $2 = vendor library suffix (5.1, 52, ...)
  dest="$VENDOR/lua/$1/linux"
  mkdir -p "$dest"
  install -m 0644 "/usr/lib/liblua$1.a"  "$dest/liblua$2.a"
  install -m 0755 "/usr/lib/liblua$1.so" "$dest/liblua$2.so"
}
rm -rf "$VENDOR"/lua/*/linux
if [ "$VENDOR_ARCH" = linux-amd64 ]; then
  install_lua 5.1 5.1
  install_lua 5.2 52
  install_lua 5.3 53
  install_lua 5.4 54
fi

# raylib and raygui are the one part of vendor/ with no C source in-tree at all
# -- upstream checks in binaries only. Drop every one of them and install the
# libraries the `raylib` and `raygui` packages built from source.
rm -rf "$VENDOR"/raylib/linux "$VENDOR"/raylib/linux-arm64

case "$VENDOR_ARCH" in
  linux-amd64) RAYLIB_DIR="$VENDOR/raylib/linux" ;;
  linux-arm64) RAYLIB_DIR="$VENDOR/raylib/linux-arm64" ;;
esac
mkdir -p "$RAYLIB_DIR"
install -m 0644 /usr/lib/libraylib.a         "$RAYLIB_DIR/libraylib.a"
install -m 0755 /usr/lib/libraylib.so.6.0.0  "$RAYLIB_DIR/libraylib.so.600"

# The arm64 static path in the bindings points at a linux-arm/ directory that
# has never existed -- the shared path two lines below it says linux-arm64. Fix
# it so the static library above is actually linkable, and fail loudly if a
# version bump fixes it upstream and makes this sed a silent no-op.
if [ "$VENDOR_ARCH" = linux-arm64 ]; then
  grep -q '"linux-arm/libraylib.a"' "$VENDOR/raylib/raylib.odin"
  sed -i 's|"linux-arm/libraylib.a"|"linux-arm64/libraylib.a"|' "$VENDOR/raylib/raylib.odin"
fi

# raygui's bindings look in linux/ on every arch, so it does not follow the
# per-arch layout raylib uses.
mkdir -p "$VENDOR/raylib/linux"
install -m 0644 /usr/lib/libraygui.a  "$VENDOR/raylib/linux/libraygui.a"
install -m 0755 /usr/lib/libraygui.so "$VENDOR/raylib/linux/libraygui.so"

# The wasm archives upstream ships are emscripten output; ours come from the
# same source through the emscripten package.
rm -rf "$VENDOR/raylib/wasm"
mkdir -p "$VENDOR/raylib/wasm"
install -m 0644 /usr/lib/emscripten/libraylib.web.a "$VENDOR/raylib/wasm/libraylib.web.a"
install -m 0644 /usr/lib/emscripten/libraygui.a     "$VENDOR/raylib/wasm/libraygui.a"

# --- wasm objects -----------------------------------------------------------
# Upstream checks in prebuilt .o files for the wasm targets too. stb, cgltf and
# box2d all build theirs with plain clang -- box2d's wasm.Makefile says outright
# that it only pretends to be emscripten -- so these are rebuilt from source.
# The vendor Makefiles locate their sysroot with `odin root`; putting the
# compiler we just built on PATH resolves that to the source tree, whose
# libc-shim is the same one we install.
export PATH="$BUILD_ROOT:$PATH"
WASM_CC="clang -ffile-prefix-map=$BUILD_ROOT=/builddir -ffile-prefix-map=$VENDOR=/builddir"

rm -f "$VENDOR"/stb/lib/*_wasm.o "$VENDOR"/cgltf/lib/cgltf_wasm.o
make -C "$VENDOR/stb/src"   CC="$WASM_CC" wasm
make -C "$VENDOR/cgltf/src" CC="$WASM_CC" wasm

# box2d's wasm.Makefile expects to run beside an unpacked box2d source tree and
# writes into ./lib, so it runs out of the build root rather than the vendor dir.
rm -f "$VENDOR"/box2d/lib/box2d_wasm.o "$VENDOR"/box2d/lib/box2d_wasm_simd.o
mkdir -p "$BUILD_ROOT/lib"
make -C "$BUILD_ROOT" -f "$VENDOR/box2d/wasm.Makefile" \
  VERSION="$MINIMAL_ARG_BOX2D_VERSION" CC="$WASM_CC" LD=wasm-ld
cp "$BUILD_ROOT/lib/box2d_wasm.o" "$BUILD_ROOT/lib/box2d_wasm_simd.o" "$VENDOR/box2d/lib/"
rm -rf "$BUILD_ROOT/lib"

# odin resolves ODIN_ROOT from /proc/self/exe, which follows symlinks, so this
# lands it on the collection tree installed above.
mkdir -p "$OUTPUT_DIR/usr/bin"
ln -s ../lib/odin/odin "$OUTPUT_DIR/usr/bin/odin"
