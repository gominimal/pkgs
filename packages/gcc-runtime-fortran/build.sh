#!/bin/sh
# libgfortran on its own, split from gcc-runtime (gominimal/inbox#1261).
# libgfortran.so.5 is ~8 MB, about two thirds of gcc's shared runtime, and only
# Fortran-built code (openblas, and numpy through it) loads it. A package is
# fetched whole, so keeping it out of gcc-runtime spares every C/C++/Rust
# closure the download. Copied byte for byte from the gcc build dep.
set -eu

src=/usr/lib
dst="$OUTPUT_DIR/usr/lib"
mkdir -p "$dst"

found=0
for f in "$src"/libgfortran.so*; do
  [ -e "$f" ] || [ -L "$f" ] || continue
  cp -P "$f" "$dst/"
  found=1
done
[ "$found" -eq 1 ] || { echo "ERROR: gcc build dep has no $src/libgfortran.so*" >&2; exit 1; }
[ -e "$dst/libgfortran.so.5" ] || { echo "ERROR: libgfortran.so.5 missing from gcc-runtime-fortran" >&2; exit 1; }
