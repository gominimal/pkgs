#!/bin/sh
set -eux

tar -xof "rizin-src-v${MINIMAL_ARG_VERSION}.tar.xz"
cd "rizin-v${MINIMAL_ARG_VERSION}"

mkdir build
cd build

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc

# THE use_sys_* DECISIONS ARE THE WHOLE JOB HERE, not the build.
#
# All seventeen `use_sys_*` options default to DISABLED, so out of the box
# rizin statically links its own copies of zlib, zstd, xz, lz4, pcre2, openssl,
# tree-sitter and xxhash. Those copies are then INVISIBLE to pkgscan:
# a CVE in any of them would not appear against this package, because nothing
# in the tree declares them. For a distro whose entire premise is supply-chain
# vuln tracking, shipping silently-vendored libraries is the wrong default.
#
# So flip every one we actually package, and no more:
#   zlib zstd lzma(xz) lz4 pcre2 openssl tree_sitter xxhash -> system
#
# Deliberately left VENDORED, with reasons:
#   capstone   rizin defaults to use_capstone_version=next, i.e. the
#              unreleased capstone 6 — there is no released tarball that
#              corresponds, so a "system" capstone (ours is 5.x) would be a
#              DIFFERENT disassembler than the one rizin was tested against.
#   magic      NOT a bundled libmagic, so there is nothing to unbundle. In
#              0.9.1 librz/magic is rizin's own rewrite (rz_magic_*, its own
#              parser in magic-load.c) and no source file calls the libmagic
#              API: use_sys_magic only adds -lmagic, which --as-needed drops,
#              plus a USE_LIB_MAGIC define read by nothing but rizin -V. Tried
#              in pkgs#1573: librz_magic did not NEED libmagic on either arch.
#   libzip, zydis, libmspack, softfloat, blake2, blake3
#              not packaged here (`zip` is Info-ZIP, not libzip); vendored is
#              the only option today. Each is a future pkgscan blind spot, so
#              they are named rather than left for someone to discover.
#
# --wrap-mode=nodownload is what makes the build hermetic: the official
# `rizin-src` tarball vendors its subprojects (capstone-next, tree-sitter,
# pcre2, lz4, nettle, blake2/3, libmspack, softfloat, ...), and this flag makes
# meson FAIL rather than reach for the network if one is ever missing. Note
# `liblzma` and `sigdb` ship as bare .wrap files, not bundled sources — the
# former is covered by use_sys_lzma below; the latter means no signature
# database, which is a real functional gap and not silently papered over.
meson setup \
  --prefix=/usr \
  --buildtype=release \
  --wrap-mode=nodownload \
  -Duse_sys_zlib=enabled \
  -Duse_sys_libzstd=enabled \
  -Duse_sys_lzma=enabled \
  -Duse_sys_lz4=enabled \
  -Duse_sys_pcre2=enabled \
  -Duse_sys_openssl=enabled \
  -Duse_sys_tree_sitter=enabled \
  -Duse_sys_xxhash=enabled \
  ..

ninja

DESTDIR="$OUTPUT_DIR" ninja install

# Fail closed at build time, not only in the standalone test: `enabled` makes
# meson error if a library is missing, but nothing else here would notice the
# linkage moving (e.g. a future rizin folding librz_hash into another lib).
# The system library must be a DT_NEEDED of the librz_* that uses it.
command -v readelf >/dev/null
needs() { # <librz_* stem> <NEEDED prefix>
  so=$(ls "$OUTPUT_DIR"/usr/lib/lib"$1".so.* 2>/dev/null | head -n1)
  [ -n "$so" ] || { echo "ERROR: lib$1.so.* not installed" >&2; exit 1; }
  readelf -d "$so" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p' | grep -q "^$2\.so" || {
    echo "ERROR: $so does not NEED $2 — use_sys_* fell back to the vendored copy" >&2
    exit 1
  }
}
needs rz_hash libxxhash
