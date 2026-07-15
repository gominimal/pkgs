#!/bin/sh
# ocaml-community/calendar — date/time library (github release, gs://-mirrored). Needs re + stdlib unix; dep of easy_logging → charon-ml.
set -eu
export BUILD_PATH_PREFIX_MAP="/builddir=$(pwd)"
export OCAMLPATH="/usr/lib/ocaml"
export CAML_LD_LIBRARY_PATH="/usr/lib/ocaml/stublibs"
dune build -p calendar -j "$(nproc)" @install
dune install --prefix=/usr --libdir=/usr/lib/ocaml --destdir="$OUTPUT_DIR" calendar
