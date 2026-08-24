#!/bin/sh
# ocaml/ocaml-re — pure-OCaml regex library (github release, gs://-mirrored). Dep of calendar → easy_logging → charon-ml on the OCaml→aeneas spine.
set -eu
export BUILD_PATH_PREFIX_MAP="/builddir=$(pwd)"
export OCAMLPATH="/usr/lib/ocaml"
export CAML_LD_LIBRARY_PATH="/usr/lib/ocaml/stublibs"
dune build -p re -j "$(nproc)" @install
dune install --prefix=/usr --libdir=/usr/lib/ocaml --destdir="$OUTPUT_DIR" re
