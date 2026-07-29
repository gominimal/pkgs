#!/bin/sh
set -ex

BUILD_ROOT="$PWD"

# build_odin.sh bakes ODIN_VERSION into the compiler. Without a .git directory
# it falls back to `date +%Y-%m`, which reads the wall clock and would make the
# build non-reproducible; pin it to the month of the release instead. Fail loudly
# if upstream stops stamping the version this way.
grep -q 'date +"%Y-%m"' build_odin.sh
sed -i "s|^\([[:space:]]*\)GIT_DATE=.*|\1GIT_DATE=\"${MINIMAL_ARG_VERSION_DATE}\"|" build_odin.sh

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
case "$VENDOR_ARCH" in
  linux-amd64) rm -rf "$VENDOR/raylib/linux-arm64" ;;
  linux-arm64) rm -rf "$VENDOR/raylib/linux" ;;
esac

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

# lua: the bindings reach for a bundled library only on amd64 and fall back to
# `system:lua<ver>` elsewhere, so there is nothing to build for arm64 -- but the
# checked-in amd64 blobs are still dead weight there, hence the unconditional rm.
# Upstream's shipped .so carries no SONAME, so we do not set one either.
build_lua() { # $1 = full version, $2 = library name suffix
  d="$BUILD_ROOT/lua-$1"
  make -C "$d/src" liblua.a CC=gcc \
    MYCFLAGS="-fPIC -DLUA_USE_LINUX -ffile-prefix-map=$BUILD_ROOT=/builddir"
  dest="$VENDOR/lua/${1%.*}/linux"
  mkdir -p "$dest"
  cp "$d/src/liblua.a" "$dest/liblua$2.a"
  gcc -shared -o "$dest/liblua$2.so" "$d"/src/*.o -lm -ldl
  # The bindings #panic at compile time on a missing library; fail here instead,
  # where the cause is visible.
  test -s "$dest/liblua$2.a"
  test -s "$dest/liblua$2.so"
}
rm -rf "$VENDOR"/lua/*/linux
if [ "$VENDOR_ARCH" = linux-amd64 ]; then
  build_lua "$MINIMAL_ARG_LUA51_VERSION" 5.1
  build_lua "$MINIMAL_ARG_LUA52_VERSION" 52
  build_lua "$MINIMAL_ARG_LUA53_VERSION" 53
  build_lua "$MINIMAL_ARG_LUA54_VERSION" 54
fi

# odin resolves ODIN_ROOT from /proc/self/exe, which follows symlinks, so this
# lands it on the collection tree installed above.
mkdir -p "$OUTPUT_DIR/usr/bin"
ln -s ../lib/odin/odin "$OUTPUT_DIR/usr/bin/odin"
