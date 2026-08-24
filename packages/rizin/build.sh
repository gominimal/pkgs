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
# rizin statically links its own copies of zlib, zstd, xz, lz4, pcre2, openssl
# and tree-sitter. Those copies are then INVISIBLE to pkgscan: a CVE in any of
# them would not appear against this package, because nothing in the tree
# declares them. For a distro whose entire premise is supply-chain vuln
# tracking, shipping seven silently-vendored libraries is the wrong default.
#
# So flip every one we actually package, and no more:
#   zlib zstd lzma(xz) lz4 pcre2 openssl tree_sitter   -> system
#
# Deliberately left VENDORED, with reasons:
#   capstone   rizin defaults to use_capstone_version=next, i.e. the
#              unreleased capstone 6 — there is no released tarball that
#              corresponds, so a "system" capstone would be a DIFFERENT
#              disassembler than the one rizin was tested against.
#   libzip, magic, zydis, xxhash, libmspack, softfloat, blake2, blake3
#              not packaged here; vendored is the only option today. Each is a
#              future pkgscan blind spot, so they are named rather than left
#              for someone to discover.
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
  ..

ninja

DESTDIR="$OUTPUT_DIR" ninja install
