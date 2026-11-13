#!/bin/sh
set -ex

BUILD_ROOT="$PWD"

# Makes `-no-threaded-checker` serialise every compiler phase, not just the
# procedure-body pass, so that odin can emit byte-identical binaries. Nothing in
# the default build path changes; see the patch header for the full reasoning.
patch -Np1 -i "$BUILD_ROOT/odin-deterministic-serial-thread-pool.patch"

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

# --- LLVM 22 -----------------------------------------------------------------
# odin supports LLVM 17-22 and the default llvm is 23, so it builds on the
# prefixed llvm-22. Everything LLVM it touches is pinned to /usr/lib/llvm-22:
# the compiler that builds it, the libLLVM it links (with a RUNPATH, since the
# prefix is not on the loader path), the clang it drives as its linker at run
# time, and the wasm-ld it runs for wasm targets.
LLVM_PREFIX=/usr/lib/llvm-22
export PATH="$LLVM_PREFIX/bin:$PATH"
case "$("$LLVM_PREFIX/bin/llvm-config" --version)" in
  22.*) ;;
  *) echo "odin needs LLVM 22 from $LLVM_PREFIX" >&2; exit 1 ;;
esac

# Upstream links by running `clang` from PATH (ODIN_CLANG_PATH overrides it) and
# `wasm-ld` from PATH. Nothing puts llvm-22 on PATH where odin runs: without the
# default llvm in the closure there is no `clang` at all, and with it a bare
# `clang` is LLVM 23's -- a different toolchain from the one odin's own codegen
# (and its `-lto` bitcode) comes from. Bake in the absolute paths;
# ODIN_CLANG_PATH still overrides. sed exits 0 on no match, so assert each
# substitution landed and that no bare `clang ` / `wasm-ld ` command string is left.
sed -i 's|clang_path = "clang";|clang_path = "'"$LLVM_PREFIX"'/bin/clang";|' src/linker.cpp
grep -q "clang_path = \"$LLVM_PREFIX/bin/clang\";" src/linker.cpp
sed -i 's|"wasm-ld %s -o |"'"$LLVM_PREFIX"'/bin/wasm-ld %s -o |' src/linker.cpp
grep -q "\"$LLVM_PREFIX/bin/wasm-ld %s -o " src/linker.cpp
if grep -nE '"(clang|wasm-ld) ' src/linker.cpp; then exit 1; fi

export CXX="$LLVM_PREFIX/bin/clang++"
export LLVM_CONFIG="$LLVM_PREFIX/bin/llvm-config"
export CPPFLAGS="-ffile-prefix-map=$(pwd)=/builddir"
export CXXFLAGS="$MARCH -pipe -gno-record-gcc-switches"
export LDFLAGS="-Wl,--build-id=none -Wl,-rpath,$LLVM_PREFIX/lib"

# `release` compiles with -O3; `release-native` would add -march=native, which
# is not reproducible across builders.
./build_odin.sh release

ODIN_ROOT="$OUTPUT_DIR/usr/lib/odin"

# The compiler must load llvm-22's libLLVM through its own RUNPATH (nothing sets
# LD_LIBRARY_PATH where odin runs), and report LLVM 22.
readelf -d odin | grep -E 'NEEDED.*libLLVM\.so\.22'
readelf -d odin | grep -E '(RUNPATH|RPATH).*'"$LLVM_PREFIX/lib"
env -u LD_LIBRARY_PATH ./odin report | grep -E 'LLVM 22\.'

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
rm -f "$VENDOR"/box2d/lib/box2d_darwin*.a

# Android: classes.dex is a prebuilt Dalvik blob that `odin bundle android`
# copies into an APK. Its Java source is in-tree, but turning that into dex
# needs the Android SDK's d8, which nothing here provides -- and neither is the
# rest of what `odin bundle android` runs (aapt2, bundletool, zipalign).
rm -f "$VENDOR/android/java/classes.dex"

# The other Linux arch: we build per-arch, so it is dead weight.
rm -rf "$VENDOR/box3d/lib/$VENDOR_ARCH_OTHER"

# Reproducibility: the vendor build scripts hardcode their own -O flags and never
# read $CFLAGS, so -ffile-prefix-map has to ride in on $CC. stb and
# cgltf use assert(), which bakes __FILE__ into the objects without it.
VENDOR_CC="gcc -ffile-prefix-map=$VENDOR=/builddir"

# box3d, stb and cgltf ship their full C source in-tree, so these need no
# network access and no dependency beyond the C toolchain we already have.
# Upstream ships no Linux build of stb or cgltf at all — it expects users to run
# these same build scripts by hand — so building them here is net-new coverage.
(
  cd "$VENDOR/box3d/src"
  rm -rf ../lib/linux-*
  # Upstream's build.sh calls `cc`, which the sandbox does not provide.
  $VENDOR_CC -c -O2 -std=c17 -fPIC -Iinclude src/*.c
  mkdir -p "../lib/$VENDOR_ARCH"
  ar -D rcs "../lib/$VENDOR_ARCH/libbox3d.a" ./*.o
  rm -f ./*.o
)
# stb and cgltf replaced their Makefiles with build_*.sh scripts. Each cds into
# $ODIN_ROOT/vendor/<lib>/src, so ODIN_ROOT pins them to the tree we install.
CC="$VENDOR_CC" AR="ar -D" ODIN_ROOT="$ODIN_ROOT" sh "$VENDOR/stb/src/build_stb.sh" unix
CC="$VENDOR_CC" AR="ar -D" ODIN_ROOT="$ODIN_ROOT" sh "$VENDOR/cgltf/src/build_cgltf.sh" unix

# box2d ships bindings but no Linux library and no in-tree C source, so its
# tarball is a Source above rather than something we compile in place. Since
# 3.2 box2d picks AVX2 or SSE2 at run time (contact_solver_w8.c enables AVX2
# for itself), so there is one library per arch. This is upstream's
# build_box2d.sh -- every src/*.c with its flags, into one archive -- minus the
# download, and outside the vendor tree so no scratch lands in the output.
B2_SRC="$BUILD_ROOT/box2d-$MINIMAL_ARG_BOX2D_VERSION"
B2_OBJ="$BUILD_ROOT/box2d-obj"
case "$VENDOR_ARCH" in
  linux-amd64) B2_LIB=box2d_other_amd64.a ;;
  linux-arm64) B2_LIB=box2d_other.a ;;
esac
# The bindings name exactly this file; fail here, not in a consumer's link, if
# a bump renames it again.
grep -q "\"lib/$B2_LIB\"" "$VENDOR/box2d/lib.odin"
rm -rf "$B2_OBJ"
mkdir -p "$B2_OBJ"
for src in "$B2_SRC"/src/*.c; do
  gcc -c -O2 -DNDEBUG -ffp-contract=off -std=gnu17 -fPIC \
    -ffile-prefix-map="$BUILD_ROOT=/builddir" \
    -I"$B2_SRC/include" -I"$B2_SRC/src" \
    "$src" -o "$B2_OBJ/$(basename "$src" .c).o"
done
rm -f "$VENDOR/box2d/lib/$B2_LIB"
ar -D rcs "$VENDOR/box2d/lib/$B2_LIB" "$B2_OBJ"/*.o
rm -rf "$B2_OBJ"

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
  install_lua 5.5 55
fi

# raylib is the one part of vendor/ with no C source in-tree at all -- upstream
# checks in binaries only. Drop every one of them and install the libraries the
# `raylib` package built from source. The bindings name the shared library by
# raylib's API version (libraylib.so.620 for 6.2), and upstream fixed the arm64
# static path our recipe used to sed (linux-arm/ -> linux-arm64/); fail here if
# either moves.
grep -q '"linux/libraylib.so.620"' "$VENDOR/raylib/raylib.odin"
grep -q '"linux-arm64/libraylib.a"' "$VENDOR/raylib/raylib.odin"
rm -rf "$VENDOR"/raylib/linux "$VENDOR"/raylib/linux-arm64

case "$VENDOR_ARCH" in
  linux-amd64) RAYLIB_DIR="$VENDOR/raylib/linux" ;;
  linux-arm64) RAYLIB_DIR="$VENDOR/raylib/linux-arm64" ;;
esac
mkdir -p "$RAYLIB_DIR"
install -m 0644 /usr/lib/libraylib.a         "$RAYLIB_DIR/libraylib.a"
install -m 0755 /usr/lib/libraylib.so.6.2.0  "$RAYLIB_DIR/libraylib.so.620"

# raygui's Linux bindings link `system:raygui`, which resolves against the
# raygui package (a runtime dep), so no copy goes into the vendor tree. Fail
# loudly if they go back to a vendored path.
grep -q 'foreign import lib "system:raygui"' "$VENDOR/raylib/raygui.odin"

# The wasm archives upstream ships are emscripten output; ours come from the
# same source through the emscripten package.
rm -rf "$VENDOR/raylib/wasm"
mkdir -p "$VENDOR/raylib/wasm"
install -m 0644 /usr/lib/emscripten/libraylib.web.a "$VENDOR/raylib/wasm/libraylib.web.a"
install -m 0644 /usr/lib/emscripten/libraygui.a     "$VENDOR/raylib/wasm/libraygui.a"

# --- wasm objects -----------------------------------------------------------
# Upstream checks in prebuilt .o files for the wasm targets too. stb, cgltf,
# box2d and box3d all build theirs with plain clang -- box2d's wasm.Makefile
# says outright that it only pretends to be emscripten -- so these are rebuilt
# from source. Their sysroot is $ODIN_ROOT/vendor/libc-shim, the copy we install.
WASM_CC="clang -ffile-prefix-map=$BUILD_ROOT=/builddir -ffile-prefix-map=$VENDOR=/builddir"

rm -f "$VENDOR"/stb/lib/*_wasm.o "$VENDOR"/cgltf/lib/cgltf_wasm.o
CC="$WASM_CC" ODIN_ROOT="$ODIN_ROOT" sh "$VENDOR/stb/src/build_stb.sh" wasm
CC="$WASM_CC" ODIN_ROOT="$ODIN_ROOT" sh "$VENDOR/cgltf/src/build_cgltf.sh" wasm

# box2d's wasm.Makefile expects to run beside an unpacked box2d-<version>/ and
# its own wasm/include (pthread/semaphore stand-ins), and writes into ./lib. The
# build root already holds box2d-<version>/; give it wasm/ and lib/ beside it.
rm -f "$VENDOR"/box2d/lib/box2d_wasm.o "$VENDOR"/box2d/lib/box2d_wasm_simd.o
test ! -e "$BUILD_ROOT/wasm"
test ! -e "$BUILD_ROOT/lib"
cp -r "$VENDOR/box2d/wasm" "$BUILD_ROOT/wasm"
mkdir -p "$BUILD_ROOT/lib"
make -C "$BUILD_ROOT" -f "$VENDOR/box2d/wasm.Makefile" \
  VERSION="$MINIMAL_ARG_BOX2D_VERSION" ODIN_ROOT="$ODIN_ROOT" CC="$WASM_CC" LD=wasm-ld
cp "$BUILD_ROOT/lib/box2d_wasm.o" "$BUILD_ROOT/lib/box2d_wasm_simd.o" "$VENDOR/box2d/lib/"
rm -rf "$BUILD_ROOT/lib" "$BUILD_ROOT/wasm"

# box3d checks in a prebuilt box3d_wasm.o as well. This is the wasm half of
# upstream's vendor/box3d/src/build.sh (the native half is the box3d block
# above), with the same flags.
B3_WASM="$BUILD_ROOT/box3d-wasm"
rm -rf "$B3_WASM"
mkdir -p "$B3_WASM"
rm -f "$VENDOR/box3d/lib/box3d_wasm.o"
(
  cd "$VENDOR/box3d/src"
  for src in src/*.c wasm_compat.c; do
    $WASM_CC -c -O3 -std=gnu17 --target=wasm32 \
      --sysroot="$ODIN_ROOT/vendor/libc-shim" \
      -Iinclude -include wasm_compat.h \
      -DBOX3D_DISABLE_SIMD -DNDEBUG \
      "$src" -o "$B3_WASM/$(basename "$src" .c).o"
  done
)
wasm-ld -r -o "$VENDOR/box3d/lib/box3d_wasm.o" "$B3_WASM"/*.o
rm -rf "$B3_WASM"

# odin resolves ODIN_ROOT from /proc/self/exe, which follows symlinks, so this
# lands it on the collection tree installed above.
mkdir -p "$OUTPUT_DIR/usr/bin"
ln -s ../lib/odin/odin "$OUTPUT_DIR/usr/bin/odin"
