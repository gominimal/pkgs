#!/bin/sh
set -e

tar -xof tar-1.35.tar.xz
cd tar-1.35

# tar 1.35 rolls its own static acl_*_file_at() wrappers in src/xattrs.c
# ("acl-at wrappers, TODO: move to gnulib in future?"). libacl 2.4.0 added
# those exact names as public functions (the CVE-2026-54369 symlink-traversal
# fix), so tar's declarations now collide: "conflicting types for
# 'acl_get_file_at'". No upstream tar release fixes this yet (1.35 is latest),
# and tar's 3-arg call sites can't use libacl's 4-arg version — so rename tar's
# internal wrappers out of the way. Drop this once tar >1.35 (or a gnulib
# re-import) handles the collision.
sed -i -E 's/\b(acl_get_file_at|acl_set_file_at|acl_delete_def_file_at)\b/tar_\1/g' src/xattrs.c
grep -q 'tar_acl_get_file_at' src/xattrs.c || { echo "tar acl-wrapper rename failed" >&2; exit 1; }

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O3 -pipe -gno-record-gcc-switches -Wl,--build-id=none -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr

make -j$(nproc)
# TODO "setfattr: dir/file1: Operation not permitted"
# make check
make DESTDIR=$OUTPUT_DIR install
