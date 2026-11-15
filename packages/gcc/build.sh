#!/usr/bin/bash
set -e

tar -xof gcc-15.2.0.tar.xz
cd gcc-15.2.0

case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
  aarch64)
    sed -e '/mabi.lp64=/s/lib64/lib/' \
        -i.orig gcc/config/aarch64/t-aarch64-linux
  ;;
esac

mkdir -v build
cd build

# TODO
# --enable-host-pie
# --enable-nls

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O3 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"
export ARFLAGS=Drc

# glibc 2.43 implements ISO C23 const-preserving string macros: strchr,
# strrchr, strstr, memchr, etc. now return a `const char *` when given a
# `const char *`. gcc-15.2.0 predates this, so its libgomp source
# (libgomp/affinity-fmt.c: `char *q = strchr (p + 1, '}');`) assigns the
# result to a plain `char *` and trips -Werror=discarded-qualifiers, failing
# the build. The pointer is never written through (only used for `q - p`), so
# this is a source-pedantry mismatch, not a runtime bug.
#
# Downgrade ONLY that one warning (everything else stays -Werror), for gcc's
# own build only — the produced compiler is unaffected. CFLAGS_FOR_TARGET is
# the documented knob for target libraries like libgomp (BOOT_CFLAGS/CFLAGS
# don't reach them); see https://gcc.gnu.org/install/build.html. CFLAGS keeps
# it for gcc proper defensively.
#
# This is the interim escape hatch; gcc-16.1.0 fixes this upstream (it builds
# cleanly against glibc 2.43 — LFS pairs them with no workaround), so the
# clean follow-up is to bump gcc to 16. Refs:
#   - glibc 2.43 C23 const-preserving macros:
#       https://lists.gnu.org/archive/html/info-gnu/2026-01/msg00005.html
#   - upstream gcc libgomp fix ("Fix GCC build after glibc@cd748a6"):
#       https://www.mail-archive.com/gcc-patches@gcc.gnu.org/msg389139.html
#   - LFS GCC-16.1.0 (builds against glibc 2.43, no const workaround):
#       https://www.linuxfromscratch.org/lfs/view/development/chapter08/gcc.html
export CFLAGS="${CFLAGS} -Wno-error=discarded-qualifiers"
export CXXFLAGS="${CFLAGS}"
export CFLAGS_FOR_TARGET="${CFLAGS}"
export CXXFLAGS_FOR_TARGET="${CXXFLAGS}"

../configure \
             --prefix=/usr                      \
             --libdir=/usr/lib                   \
             --enable-languages=c,c++,fortran   \
             --enable-default-pie     \
             --enable-default-ssp     \
             --disable-multilib       \
             --disable-bootstrap      \
             --disable-fixincludes     \
             --with-system-zlib       \
             --disable-nls

make -j$(nproc)
# TODO make -k check
make DESTDIR=$OUTPUT_DIR install-strip

# A second copy of the shared runtime libraries, under a path no other object
# ships, for gcc-runtime and gcc-runtime-fortran to repack. They cannot repack
# usr/lib: their build roots also hold gcc-runtime's cycle breaker (a bootstrap
# gcc, via gcc -> gmp -> gcc-runtime), and where two layers ship one path the
# first wins by spec-hash order. On arm64 that shipped the gen-13 gcc 15
# libstdc++.so.6 and libgcc_s.so.1 in the gcc 16 canary (pkgs#1340). Symlinks
# are copied as symlinks, so the SONAME links still point at this build's files.
stage="$OUTPUT_DIR/usr/lib/gcc-runtime-stage"
mkdir -p "$stage"
for pat in 'libgcc_s.so*' 'libstdc++.so*' 'libgomp.so*' 'libatomic.so*' 'libssp.so*' 'libquadmath.so*' 'libgfortran.so*'; do
  for f in "$OUTPUT_DIR"/usr/lib/$pat; do
    [ -e "$f" ] || [ -L "$f" ] || continue
    case "$f" in *.py) continue ;; esac # libstdc++.so.6.*-gdb.py
    cp -P "$f" "$stage/"
  done
done
for so in libgcc_s.so.1 libstdc++.so.6 libgomp.so.1 libatomic.so.1 libssp.so.0 libgfortran.so.5; do
  [ -e "$stage/$so" ] || { echo "ERROR: $so missing from $stage" >&2; exit 1; }
done

# TODO
# ln -sf $OUTPUT_DIR/usr/bin/gcc $OUTPUT_DIR/usr/bin/cc
