#!/bin/sh
# fpottier/menhir (gitlab.inria.fr, gs://-mirrored) — offline parser generator.
# Installs the menhir binary + menhirLib/menhirCST/menhirSdk findlib libs.
set -eu
export BUILD_PATH_PREFIX_MAP="/builddir=$(pwd)"
export OCAMLPATH="/usr/lib/ocaml"
export CAML_LD_LIBRARY_PATH="/usr/lib/ocaml/stublibs"
dune build -p menhirCST,menhirSdk,menhirLib,menhir -j "$(nproc)" @install
dune install --prefix=/usr --libdir=/usr/lib/ocaml --destdir="$OUTPUT_DIR" \
  menhirCST menhirSdk menhirLib menhir
