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
# headers+lib under /usr, so the default search path resolves it.
./configure
make
make install
