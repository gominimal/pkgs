#!/bin/sh
# Hand-authored: zarith builds via ./configure + make (NOT dune) and installs
# through `ocamlfind install`.
set -ex
# Reproducibility (AGENTS.md C/C++): strip the build path + non-deterministic
# build-id / recorded gcc switches so two builds are byte-identical.
export CFLAGS="${CFLAGS:-} -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="${LDFLAGS:-} -Wl,--build-id=none"
export BUILD_PATH_PREFIX_MAP="/builddir=$(pwd)"
# `ocamlfind install` would write into the read-only /usr store (deps mount RO)
# and edit the shared ld.conf — redirect it into the sandbox output tree instead
# (de-risk C3: the canonical non-dune OCaml install convention).
export OCAMLFIND_DESTDIR="$OUTPUT_DIR/usr/lib/ocaml"
export OCAMLFIND_LDCONF=ignore
mkdir -p "$OCAMLFIND_DESTDIR/stublibs"
# configure probes GMP via a -lgmp test-compile; gmp (a build_dep) mounts its
# headers+lib under /usr, so the default search path resolves it. configure feeds
# $LDFLAGS to gcc via `ocamlc -ccopt` here, so the bare `-Wl,--build-id=none`
# above is what it needs.
./configure
# project.mak passes $(LDFLAGS) STRAIGHT to `ocamlmklib` (the .cma/.cmxa/libzarith
# link rules), which has its own option parser and rejects the bare
# `-Wl,--build-id=none` with "Unknown option" — it only forwards C-linker flags
# via `-ldopt`. Same var, incompatible consumer, so override it to the `-ldopt`
# form for `make` only (a make-cmdline assignment overrides the Makefile's
# `LDFLAGS=`, and LDFLAGS reaches nothing here but ocamlmklib). Keeps the build-id
# stripped on dllzarith.so for reproducibility without breaking the link.
make LDFLAGS="-ldopt -Wl,--build-id=none"
make install
