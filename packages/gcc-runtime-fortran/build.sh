#!/bin/sh
# libgfortran on its own, split from gcc-runtime (gominimal/inbox#1261).
# libgfortran.so.5 is ~8 MB, about two thirds of gcc's shared runtime, and only
# Fortran-built code (openblas, and numpy through it) loads it. A package is
# fetched whole, so keeping it out of gcc-runtime spares every C/C++/Rust
# closure the download. Copied byte for byte from the gcc build dep.
set -eu

. ./stage.sh

copy 'libgfortran.so*'
[ -e "$dst/libgfortran.so.5" ] || { echo "ERROR: libgfortran.so.5 missing from gcc-runtime-fortran" >&2; exit 1; }
one_real_file 'libgfortran.so.5.*' libgfortran.so.5
