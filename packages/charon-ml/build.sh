#!/bin/sh
# AeneasVerif/charon-ml (github, gs://-mirrored) — offline OCaml bindings.
# Builds only the OCaml `charon` + `name_matcher_parser` libraries; the Rust
# charon binary in the same repo is out of scope (dune ignores it).
set -eu
export BUILD_PATH_PREFIX_MAP="/builddir=$(pwd)"
export OCAMLPATH="/usr/lib/ocaml"
export CAML_LD_LIBRARY_PATH="/usr/lib/ocaml/stublibs"
dune build -p charon,name_matcher_parser -j "$(nproc)" @install
dune install --prefix=/usr --libdir=/usr/lib/ocaml --destdir="$OUTPUT_DIR" \
  charon name_matcher_parser
