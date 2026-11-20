#!/bin/sh
set -e

# The CPU kernels (ggml-cpu) are built once per microarchitecture and the best one
# for the host is picked at run time (GGML_BACKEND_DL + GGML_CPU_ALL_VARIANTS,
# below), so CFLAGS carry only each arch's baseline, the gcc default spelled out.
# Each variant appends its own -march (arm64, which overrides this one) or -m flags
# (x86, which add to it). A higher floor here leaks into every variant and into the
# feature probe that scores them: with the old -march=x86-64-v3 the "x64" and "sse42"
# variants would carry AVX2 and the probe itself could SIGILL on a pre-AVX2 CPU. The
# rest (libllama, ggml-base, the server) builds at the baseline too, as upstream's
# release builds do; the hot loops are in ggml-cpu.
#
# VARIANTS is the exact set ggml/src/CMakeLists.txt defines for Linux at this
# version. build.sh checks the build produced exactly these, so a bump that adds,
# renames or drops one fails here instead of shipping a different set.
case $(uname -m) in
  x86_64)
    MARCH="-march=x86-64"
    VARIANTS="x64 sse42 sandybridge ivybridge piledriver haswell skylakex cannonlake cascadelake icelake cooperlake zen4 alderlake sapphirerapids"
    ;;
  aarch64)
    MARCH="-march=armv8-a"
    VARIANTS="armv8.0_1 armv8.2_1 armv8.2_2 armv8.2_3 armv8.6_1 armv8.6_2 armv9.2_1 armv9.2_2"
    ;;
  *)
    echo "ERROR: no ggml CPU variant list for $(uname -m)" >&2
    exit 1
    ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# The embedded web UI (llama-ui, linked into libllama-server-impl.so). Left to
# itself, scripts/ui-assets.cmake downloads dist.tar.gz from Hugging Face at build
# time, and with no .git in the tarball the build number is 0, so it falls back to
# the moving `latest` tag: a different UI got embedded as upstream published new
# ones, which was the 2026-10 prod-pair diff (31% of libllama-server-impl.so,
# identical symbols). Instead, the b12359 UI is a pinned Source, unpacked where the
# script looks first (tools/ui/dist), and both fetch paths are off. The script
# gzips each asset without -n, so the gzip header carries the file's mtime: pin
# the mtimes too. Not to SOURCE_DATE_EPOCH: the sandbox's is 0, which gzip can't
# store ("file timestamp out of range", exit 2), so 1980-01-01 instead.
mkdir -p tools/ui/dist
tar -xof "${MINIMAL_ARG_VERSION}-dist.tar.gz" -C tools/ui/dist
test -s tools/ui/dist/index.html || {
  echo "ERROR: pinned llama-ui dist has no index.html" >&2
  exit 1
}
find tools/ui/dist -exec touch -h -d @315532800 {} +

# The UI's third-party notices (pkgs#994) are generated outside the build by
# gen-ui-notices.py, from this version's tools/ui/package-lock.json. Fail closed
# if they weren't regenerated for what is built here: the UI version, the dist
# and the lock recorded in the header must all match. An empty header field
# fails sha256sum --strict -c too.
notices=./ui-THIRD-PARTY-NOTICES
notices_field() { sed -n "s/^$1: //p" "$notices" | head -n1; }
[ "$(notices_field 'llama-ui version')" = "$MINIMAL_ARG_VERSION" ] || {
  echo "ERROR: $notices is for llama-ui '$(notices_field 'llama-ui version')', not $MINIMAL_ARG_VERSION: rerun gen-ui-notices.py" >&2
  exit 1
}
echo "$(notices_field 'llama-ui dist sha256')  ${MINIMAL_ARG_VERSION}-dist.tar.gz" | sha256sum --strict -c -
echo "$(notices_field 'package-lock sha256')  tools/ui/package-lock.json" | sha256sum --strict -c -

# CVE-2023-45663: the vendored stb_image 2.30 ignores stbi__getn's return in the
# TGA and HDR loaders, so a short file leaves uninitialized heap/stack in the
# decoded pixels. llama-server decodes image_url data with stbi_load_from_memory
# and every stb_image decoder is compiled in. The patch is upstream's own fix,
# nothings/stb cd44845 ("stb_image: Fix bugs in TGA and HDR", v2.31), unchanged.
# Both hashes are checked, so a different vendored copy fails here instead of
# patching the wrong file, and a partial apply cannot pass. Drop when llama.cpp
# vendors stb_image >= 2.31.
echo "594c2fe35d49488b4382dbfaec8f98366defca819d916ac95becf3e75f4200b3  vendor/stb/stb_image.h" | sha256sum -c -
patch -Np1 -i ./stb-cve-2023-45663.patch
echo "a604136650368a391554f4a4b45f285d4c8fe94c7bf28a414b37edd28407899e  vendor/stb/stb_image.h" | sha256sum -c -

# With GGML_BACKEND_DL, ggml_backend_load_best() searches GGML_BACKEND_DIR, then the
# executable's directory, then the CURRENT directory, and dlopen()s every
# libggml-<name>-*.so it finds there before scoring them (constructors run on load).
# Starting llama-server/llama-cli in a directory someone else can write (a downloaded
# model folder, a cloned repo) would run a planted library. The static build never
# did this. The patch makes an installed build (GGML_BACKEND_DIR set) search only
# /usr/lib/ggml; GGML_BACKEND_PATH, an explicit opt-in, still works. Both hashes are
# checked: a changed loader fails here instead of patching blind.
echo "0a23a627cec97926fb1fbb2b1bf4fa7fed4900aa21b0215302eced797231578b  ggml/src/ggml-backend-reg.cpp" | sha256sum -c -
patch -Np1 -i ./ggml-backend-dir-only.patch
echo "607514a82eb47dbf21994914ea3c6abe7c8c5aca1a48d5d620f74f6c7d1f7815  ggml/src/ggml-backend-reg.cpp" | sha256sum -c -

# The x86 variant scorer (ggml_backend_cpu_x86_score) reads CPUID feature bits only;
# upstream marks it "FIXME: this does not check for OS support"
# (ggml/src/ggml-cpu/arch/x86/cpu-feats.cpp:264 at b12359, unchanged on master). A
# host whose CPU has AVX-512 (or AVX/AVX2, or AMX) while the OS or hypervisor leaves
# that register state off in XCR0 would load skylakex (etc.) and SIGILL, where
# haswell runs. The patch reads XCR0 (XGETBV, only when CPUID.1:ECX.OSXSAVE is set)
# and counts AVX/AVX2/FMA/F16C/AVX-VNNI only with XCR0[2:1], AVX-512 only with
# XCR0[7:5] too, and AMX only with XCR0[18:17]; amx.cpp's arch_prctl request is
# untouched. Scores are otherwise unchanged. Upstream has open, unmerged PRs for this
# (ggml-org/llama.cpp#19514, #20940); drop the patch when one lands.
# https://github.com/gominimal/pkgs/pull/1559#discussion_r4621978298
echo "b0f6aaaeb0b12a4f3e15ceec14d0c2031633f91e864a6c15954a001d6390f6d4  ggml/src/ggml-cpu/arch/x86/cpu-feats.cpp" | sha256sum -c -
patch -Np1 -i ./ggml-cpu-feats-xcr0.patch
echo "33c17ca73a60a7fb30eb399a4f8e6562062b82b3ea02907e0156765df111a080  ggml/src/ggml-cpu/arch/x86/cpu-feats.cpp" | sha256sum -c -

# GGML_NATIVE=OFF: ggml already defaults it OFF when SOURCE_DATE_EPOCH is set (the
# sandbox sets it), and it must be: -march=native would follow the build host's CPU,
# and ggml refuses GGML_NATIVE with GGML_BACKEND_DL.
#
# GGML_BACKEND_DL + GGML_CPU_ALL_VARIANTS: one libggml-cpu-<variant>.so per entry in
# $VARIANTS, dlopen()ed at run time. ggml_backend_load_all() loads each candidate,
# asks its ggml_backend_score() (a feature probe compiled without the variant's
# flags), and keeps the highest-scoring one. On arm64 that brings in the DOTPROD,
# FP16, SVE, i8mm, SVE2 and SME kernels plain armv8-a left out (pkgs#975); on x86 it
# runs on pre-AVX2 CPUs and uses AVX-512/VNNI/AMX where present. The set is fixed by
# these options, not the build host, so the output is the same on every builder.
# armv9.2 (+sme) needs gcc >= 14.
#
# GGML_BACKEND_DIR: where the loader looks first. Its other places are the
# executable's own directory (resolved through /proc/self/exe, which need not be
# /usr/bin) and the current directory. The variants are plugins, not libraries
# anything links, so they get their own directory instead of the linker's path.
#
# Tests and examples are not shipped; skipping them offsets part of the cost of
# building ggml-cpu 8 (arm64) or 14 (x86_64) times.
cmake -B build \
  -DGGML_NATIVE=OFF \
  -DGGML_BACKEND_DL=ON \
  -DGGML_CPU_ALL_VARIANTS=ON \
  -DGGML_BACKEND_DIR=/usr/lib/ggml \
  -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_UI=OFF \
  -DLLAMA_USE_PREBUILT_UI=OFF
cmake --build build --config Release -j $(nproc)

# Exactly the expected variants, and no single non-variant CPU backend.
built=$(cd build/bin && ls libggml-cpu-*.so | sed 's/^libggml-cpu-//; s/\.so$//' | sort | tr '\n' ' ')
want=$(printf '%s\n' $VARIANTS | sort | tr '\n' ' ')
if [ "$built" != "$want" ]; then
  echo "ERROR: ggml CPU variants differ from VARIANTS" >&2
  echo "  built: $built" >&2
  echo "  want:  $want" >&2
  exit 1
fi
if [ -e build/bin/libggml-cpu.so ]; then
  echo "ERROR: build/bin/libggml-cpu.so exists: GGML_CPU_ALL_VARIANTS was not applied" >&2
  exit 1
fi

mkdir -pv $OUTPUT_DIR/usr/{bin,lib} $OUTPUT_DIR/usr/lib/ggml

# The shared libraries ship as built: lib*.so -> lib*.so.0 -> lib*.so.0.x.y.
# `install build/bin/*.so` followed each link and wrote the library under its
# unversioned name only, so the binaries' DT_NEEDED (the SONAME, libllama.so.0
# etc.) was never shipped and llama-cli/llama-server exited 127 at startup.
cp -av build/bin/*.so* $OUTPUT_DIR/usr/lib/
# The CPU variants go where GGML_BACKEND_DIR points.
mv -v $OUTPUT_DIR/usr/lib/libggml-cpu-*.so* $OUTPUT_DIR/usr/lib/ggml/
install -vm755 build/bin/llama-{cli,server} $OUTPUT_DIR/usr/bin/
install -Dvm644 "$notices" $OUTPUT_DIR/usr/share/licenses/llama.cpp/ui-THIRD-PARTY-NOTICES

# Fail closed: every library a shipped ELF needs that this build produced (it is
# in build/bin) must be in the output under that exact name. `found` keeps the
# check from passing vacuously (llama-cli alone needs libllama.so.0).
command -v readelf >/dev/null
missing=0
found=0
for f in $OUTPUT_DIR/usr/bin/* $OUTPUT_DIR/usr/lib/*.so* $OUTPUT_DIR/usr/lib/ggml/*.so*; do
  [ -L "$f" ] && continue
  for lib in $(readelf -d "$f" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p'); do
    [ -e "build/bin/$lib" ] || continue
    found=$((found + 1))
    if [ ! -e "$OUTPUT_DIR/usr/lib/$lib" ]; then
      echo "ERROR: $f needs $lib, built here but not installed" >&2
      missing=1
    fi
  done
done
[ "$found" -gt 0 ] || { echo "ERROR: no DT_NEEDED resolved to build/bin" >&2; exit 1; }
[ "$missing" = 0 ]
