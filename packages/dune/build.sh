#!/bin/sh
set -ex

# `.tbz` isn't auto-extracted by minimal; unpack + enter the source tree.
tar -xf "dune-${MINIMAL_ARG_VERSION}.tbz"
cd "dune-${MINIMAL_ARG_VERSION}"

export BUILD_PATH_PREFIX_MAP="/builddir=$(pwd)"

# Self-bootstrap: `ocaml boot/bootstrap.ml` compiles a first dune from the
# tarball's own sources into ./_boot/dune.exe — no host dune, no network.
ocaml boot/bootstrap.ml
BIN=./_boot/dune.exe

# Build the `dune` binary. NOTE: `dune-configurator` (the findlib library that
# core_unix / jst-config's build-time `discover` executables need) also lives in
# this tarball, but it depends on `csexp` — a Tier-1 library we package
# separately. Add `dune-configurator` here (or as its own package) once `csexp`
# lands; the toolchain trio + pure-dune libs don't need it. (roadmap C2)
"$BIN" build @install -p dune --profile dune-bootstrap

# dune install honors --destdir for the DESTDIR-style sandbox layout.
"$BIN" install --prefix=/usr --libdir=/usr/lib/ocaml --destdir="$OUTPUT_DIR" dune
