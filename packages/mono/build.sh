#!/bin/sh
set -e

tar -xof "mono-${MINIMAL_ARG_VERSION}.tar.gz"
cd "mono-${MINIMAL_ARG_VERSION}"

# The prepared tarball was archived on macOS, which scatters AppleDouble
# "._*" sidecar files through the tree. mono's C# build globs `*.cs` and
# feeds these binary sidecars to the compiler (CS1056 "unexpected character"
# on e.g. external/cecil/Mono.Cecil.PE/._TextMap.cs). Strip them all.
find . -name '._*' -type f -delete

# Provide a 'which' shim (not present in the sandbox, needed by BTLS Makefile)
mkdir -p shims
cat > shims/which << 'SHIM'
#!/bin/sh
for cmd in "$@"; do
  IFS=: ; for dir in $PATH; do
    if [ -x "$dir/$cmd" ]; then echo "$dir/$cmd"; unset IFS; exit 0; fi
  done
done
unset IFS; exit 1
SHIM
chmod +x shims/which
export PATH="$(pwd)/shims:$PATH"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac

export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"
export ARFLAGS=Drc

# Fix cmake_minimum_required for newer cmake (>= 4.0 removed < 3.5 compat)
sed -i 's/cmake_minimum_required (VERSION 2\.8\.10)/cmake_minimum_required (VERSION 3.5)/' \
  mono/btls/CMakeLists.txt \
  external/boringssl/CMakeLists.txt

# Reproducibility: mono stamps build_date with a bare `date` in
# mono/mini/Makefile.am.in (the buildver-{sgen,boehm}.h recipes), which ignores
# SOURCE_DATE_EPOCH and leaks wall-clock time into mono-sgen and every AOT
# *.dll.so (the embedded "tarball <date>" runtime build-info string). Bake a
# fixed, epoch-derived date into those recipes before autogen.sh expands the
# template into Makefile.am.
BUILD_DATE="$(LC_ALL=C date -u -d "@${SOURCE_DATE_EPOCH:-0}")"
sed -i "/build_date/s|\`date\`|$BUILD_DATE|g" mono/mini/Makefile.am.in

# Reproducibility (AOT layer): mono's AOT compiler stamps a RANDOM 16-byte AOT ID
# (aot-compiler.c generate_aotid -> mono_rand) into every installed *.dll.so/.exe.so.
# mono's `deterministic` aot option suppresses it, but the default net_4_x build AOTs
# via a path that doesn't thread that option through. So neutralize the randomness at
# its source: zero the aotid. This is exactly what `deterministic` mode yields for the
# emitted image (aot_opts.deterministic only gates this aotid plus one stdout line —
# nothing else in the artifact).
sed -i 's/mono_rand_try_get_bytes (&rand_handle, aotid, 16, error);/memset (aotid, 0, 16);/' mono/mini/aot-compiler.c

# The GitHub-sourced tarball ships the raw tag tree (no generated
# `configure`), so regenerate the autotools build system first. mono's
# autogen.sh runs autoreconf and then invokes ./configure with "$@".
NOCONFIGURE=1 ./autogen.sh
./configure \
  --prefix=/usr \
  --sysconfdir=/usr/etc \
  --disable-nls \
  --with-mcs-docs=no \
  --with-sgen=yes \
  --with-ikvm=no \
  --with-monodroid=no \
  --with-monotouch=no \
  --with-xammac=no

# Cap parallelism to nproc/4 (matches packages/foundationdb). Mono's
# bootstrap (byacc + jay + corlib + the runtime) is memory-greedy at
# -j32 and OOMs the whole build.
JOBS=$(( $(nproc) / 4 ))
[ "$JOBS" -lt 1 ] && JOBS=1

make -j"$JOBS"
make DESTDIR=$OUTPUT_DIR install

# Remove .la files for reproducibility
find $OUTPUT_DIR -name '*.la' -delete

# Reproducibility (AOT temp-name layer): mono's AOT compiler names its temporary
# object file with a random suffix (g_file_open_tmp "mono_aot_XXXXXX") that leaks
# into each *.dll.so/*.exe.so as a local STT_FILE symbol. The default net_4_x
# build threads no temp-path to pin it, so strip the (runtime-unneeded) local
# symbols from the AOT images — this removes the random name. mono's AOT loader
# resolves via the global mono_aot_*_info symbol + offset tables, not locals, so
# this is safe (distros ship stripped mono AOT). Verified: strip --strip-unneeded
# makes the two builds' AOT images byte-identical.
find "$OUTPUT_DIR" \( -name '*.dll.so' -o -name '*.exe.so' \) -exec strip --strip-unneeded {} +
