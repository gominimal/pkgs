#!/bin/sh
# fpottier/visitors (gitlab.inria.fr, gs://-mirrored) — offline ppx + runtime lib.
set -eu
export BUILD_PATH_PREFIX_MAP="/builddir=$(pwd)"
export OCAMLPATH="/usr/lib/ocaml"
export CAML_LD_LIBRARY_PATH="/usr/lib/ocaml/stublibs"
dune build -p visitors -j "$(nproc)" @install
dune install --prefix=/usr --libdir=/usr/lib/ocaml --destdir="$OUTPUT_DIR" visitors
