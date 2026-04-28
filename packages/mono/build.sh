#!/bin/sh
set -e

tar -xof "mono-${MINIMAL_ARG_VERSION}.tar.xz"
cd "mono-${MINIMAL_ARG_VERSION}"

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
