#!/bin/sh
# Repack gcc's shared runtime libraries into a package of their own.
#
# A `subsetOf gcc [...]` runtime dep fetches all of gcc (~300 MB per arch) and
# pulls gcc's runtime_deps (gmp, mpc, mpfr, zlib, zstd) into every consumer's
# closure: minimal resolves a subset against the whole parent build
# (crates/graph transitives.rs; the remote cache is per build, not per output).
# Consumers that only load libgcc_s/libstdc++/... depend on this instead
# (gominimal/inbox#1261). The files are copied byte for byte from the gcc
# build dep, so they cannot drift from the compiler that links against them.
set -eu

src=/usr/lib
dst="$OUTPUT_DIR/usr/lib"
mkdir -p "$dst"

# copy <glob>: copy every match (files and symlinks, as they are) and fail when
# gcc has none, so a library gcc stops shipping is an error, not an empty output.
copy() {
  found=0
  for f in "$src"/$1; do
    [ -e "$f" ] || [ -L "$f" ] || continue
    case "$f" in *.py) continue ;; esac # libstdc++.so.6.*-gdb.py: debugger helper
    cp -P "$f" "$dst/"
    found=1
  done
  [ "$found" -eq 1 ] || { echo "ERROR: gcc build dep has no $src/$1" >&2; exit 1; }
}

copy 'libgcc_s.so*'
copy 'libstdc++.so*'
copy 'libgomp.so*'
copy 'libatomic.so*'
copy 'libgfortran.so*'
case $(uname -m) in
  x86_64) copy 'libquadmath.so*' ;; # gcc builds libquadmath on amd64 only
esac

# Each SONAME a consumer records in DT_NEEDED must be present.
for so in libgcc_s.so.1 libstdc++.so.6 libgomp.so.1 libatomic.so.1 libgfortran.so.5; do
  [ -e "$dst/$so" ] || { echo "ERROR: $so missing from gcc-runtime" >&2; exit 1; }
done
