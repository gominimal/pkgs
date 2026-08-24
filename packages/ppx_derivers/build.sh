#!/bin/sh
# Auto-bootstrapped from https://github.com/ocaml-ppx/ppx_derivers (ocaml/dune) by `pkgmgr bootstrap`.
set -eu
export BUILD_PATH_PREFIX_MAP="/builddir=$(pwd)"
# Dependencies resolve through findlib from the merged /usr tree; no network.
export OCAMLPATH="/usr/lib/ocaml"
export CAML_LD_LIBRARY_PATH="/usr/lib/ocaml/stublibs"
dune build -p ppx_derivers -j "$(nproc)" @install
dune install --prefix=/usr --libdir=/usr/lib/ocaml --destdir="$OUTPUT_DIR" ppx_derivers
