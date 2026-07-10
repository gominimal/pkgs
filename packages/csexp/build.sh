#!/bin/sh
set -ex

tar -xof "csexp-${MINIMAL_ARG_VERSION}.tbz"
cd "csexp-${MINIMAL_ARG_VERSION}"

export BUILD_PATH_PREFIX_MAP="/builddir=$(pwd)"
export OCAMLPATH="/usr/lib/ocaml"
export CAML_LD_LIBRARY_PATH="/usr/lib/ocaml/stublibs"

dune build -p csexp -j "$(nproc)" @install
dune install --prefix=/usr --libdir=/usr/lib/ocaml --destdir="$OUTPUT_DIR" csexp
