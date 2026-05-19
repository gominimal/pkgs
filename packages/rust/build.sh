#!/bin/sh
set -ex

export LIBSQLITE3_SYS_USE_PKG_CONFIG=1
export LIBSSH2_SYS_USE_PKG_CONFIG=1
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# DIAGNOSTIC: print whether extra_rootfs propagates /rust-stage0 to
# this nested sandbox. Builder-side hydrate_rust_stage0 should have
# written tarballs to <stage>/rust-stage0/<date>/ which hardlink into
# every sandbox via SandboxMapped::Dir. If we see "exists" + listing,
# the hardlink chain works. If "DOES NOT EXIST", the bug is in minimal's
# extra_rootfs propagation (specifically for nested transitive builds).
echo "===== rust pkg sandbox: /rust-stage0 probe ====="
if [ -d /rust-stage0 ]; then
    echo "/rust-stage0 EXISTS"
    ls -la /rust-stage0/ || true
    find /rust-stage0 -type f -maxdepth 3 | head -20
else
    echo "/rust-stage0 DOES NOT EXIST in nested rust sandbox"
fi
echo "===== sandbox rootfs probe (other extra_rootfs paths) ====="
for p in /mirror /cargo-vendor /npm-cache /pip-wheels /pnpm-store; do
    if [ -d "$p" ]; then
        echo "  $p exists (found $(find $p -maxdepth 2 -type f 2>/dev/null | wc -l) files)"
    fi
done
echo "==============================================="

# Hermetic build path: when a SLSA-grade builder has pre-staged the
# stage 0 bootstrap tarballs (sha-verified against the rust source's
# src/stage0 manifest), copy them into x.py's expected cache location
# so it doesn't try to curl static.rust-lang.org. The pre-stage layout
# is /rust-stage0/<date>/<basename>, where <date> matches the rust
# source's compiler_date.
if [ -d /rust-stage0 ]; then
    # x.py reads its date from src/stage0; whichever date dir we
    # find at /rust-stage0/, mirror it under build/cache/.
    for date_dir in /rust-stage0/*/; do
        date_basename=$(basename "$date_dir")
        mkdir -p "build/cache/$date_basename"
        cp -v "$date_dir"*.tar.xz "build/cache/$date_basename/"
    done
fi

./x.py build

DESTDIR=$OUTPUT_DIR ./x.py install

rm $OUTPUT_DIR/usr/bin/rust-gdbgui
