#!/bin/sh
set -ex

# `.tbz` isn't auto-extracted by minimal; unpack + enter the source tree.
tar -xof "yojson-${MINIMAL_ARG_VERSION}.tbz"
cd "yojson-${MINIMAL_ARG_VERSION}"

export BUILD_PATH_PREFIX_MAP="/builddir=$(pwd)"
# The offline dune-lib convention: dependencies resolve through findlib from the
# merged /usr tree (build_deps installed their trees under usr/lib/ocaml/<pkg>);
# no opam, no network. `dune build -p <pkg> @install` is exactly what opam's own
# build command uses — the `-p` disables dune's package manager.
export OCAMLPATH="/usr/lib/ocaml"
export CAML_LD_LIBRARY_PATH="/usr/lib/ocaml/stublibs"

# Skip `dune subst` (needs git, gated {dev} upstream) and never re-export
# SOURCE_DATE_EPOCH — BUILD_PATH_PREFIX_MAP already covers reproducibility.
dune build -p yojson -j "$(nproc)" @install
dune install --prefix=/usr --libdir=/usr/lib/ocaml --destdir="$OUTPUT_DIR" yojson
