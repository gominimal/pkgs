#!/bin/sh
# sapristi/easy_logging — logging library (github tarball, gs://-mirrored). Uses calendar for timestamps; a hard dep of charon-ml on the OCaml→aeneas spine.
set -eu
export BUILD_PATH_PREFIX_MAP="/builddir=$(pwd)"
export OCAMLPATH="/usr/lib/ocaml"
export CAML_LD_LIBRARY_PATH="/usr/lib/ocaml/stublibs"
dune build -p easy_logging -j "$(nproc)" @install
dune install --prefix=/usr --libdir=/usr/lib/ocaml --destdir="$OUTPUT_DIR" easy_logging
