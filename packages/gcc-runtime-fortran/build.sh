#!/bin/sh
# libgfortran on its own, split from gcc-runtime (gominimal/inbox#1261).
# libgfortran.so.5 is ~8 MB, about two thirds of gcc's shared runtime, and only
# Fortran-built code (openblas, and numpy through it) loads it. A package is
# fetched whole, so keeping it out of gcc-runtime spares every C/C++/Rust
# closure the download. Copied byte for byte from the gcc build dep.
set -eu

. ./stage.sh

# Seed pass with no Fortran in the breaker. This package is on no bootstrap
# cycle, but minimal's planner seed-builds any dependent of an unbuilt cycle
# member against that member's replace_on_cycle once its other deps are ready
# (graph/src/planner.rs dep_candidate). pkgs#1545 run d24f23c3 did exactly that:
# everything but gcc and gcc-runtime was cached. arm64's gcc breaker (gen-17
# gcc-15.2.0-glibc-seed) has no Fortran at all. A seed build is never published
# and is always rebuilt against the real gcc, so write a placeholder that
# satisfies the output glob. Its name is deliberately not libgfortran.so.5, so
# it can never shadow the real one in a seed consumer's root.
if [ "$src" = /usr/lib ]; then
  set -- /usr/lib/libgfortran.so*
  if [ ! -e "$1" ] && [ ! -L "$1" ]; then
    echo "seed pass: the gcc breaker ships no libgfortran; writing a placeholder (never published)"
    echo "gcc-runtime-fortran seed placeholder: rebuilt against the real gcc" >"$dst/libgfortran.so.seed-placeholder"
    exit 0
  fi
fi

copy 'libgfortran.so*'
[ -e "$dst/libgfortran.so.5" ] || { echo "ERROR: libgfortran.so.5 missing from gcc-runtime-fortran" >&2; exit 1; }
one_real_file 'libgfortran.so.5.*' libgfortran.so.5
