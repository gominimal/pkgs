#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS="Drc"
# OCaml natively implements the reproducible-builds BUILD_PATH_PREFIX_MAP spec —
# it rewrites embedded build paths in .cmi/.cmt/.a and debug info. Honored by
# both ./configure and make.
export BUILD_PATH_PREFIX_MAP="/builddir=$(pwd)"

# The release tarball ships a pre-generated ./configure (no autogen). Disable
# zstd (optional .cmi compression) to avoid the extra system dep.
./configure --prefix=/usr --without-zstd

# world.opt = bytecode world + native (ocamlopt) compilers, bootstrapped from
# the tarball's boot/ocamlc — no host OCaml, no network.
make -j"$(nproc)" world.opt
make install DESTDIR="$OUTPUT_DIR"

# ============================================================================================
# ★ BOOTSTRAP FIXPOINT GATE (issue #48).
#
# THE PROBLEM THIS ADDRESSES: OCaml does not build from source the way the rest of the catalogue
# does. `make world` runs boot/ocamlc — a 3.65 MB COMMITTED BYTECODE IMAGE of the compiler that
# ships inside the release tarball — and that blob compiles the stdlib and then the compiler
# itself. So "we build OCaml from source" quietly means "we trust a binary blob we did not build."
# It is the same trust-by-fiat class as the go.dev bindist that #19 retired.
#
# WHAT THIS GATE PROVES: `make bootstrap` rebuilds boot/ocamlc USING the compiler we just built,
# then compares the regenerated blob against the shipped one (tools/cmpbyt / the Makefile's own
# compare step). If they agree, the shipped blob is a FIXED POINT of the source we shipped —
# i.e. the blob is not smuggling in behaviour absent from the source tree.
#
# WHAT IT DOES *NOT* PROVE — state this plainly, because the distinction is the whole point:
# a fixpoint check does NOT defeat a Thompson attack. A blob carrying a self-reproducing backdoor
# regenerates itself and passes this gate perfectly. Only a ladder rooted outside OCaml
# (camlboot -> 4.07 -> ... -> 5.x, tracked in #48) can retire the blob. This gate raises the cost
# of a mismatch to "impossible to ignore"; it does not close the hole.
#
# Non-fatal for now (|| true on the compare): this lands as a MEASUREMENT first so we learn whether
# upstream's blob is even a fixed point for our build flags, before it can wedge the catalogue.
# Promote to fail-shut once it has been green twice.
# ============================================================================================
echo "OCAML-FIXPOINT: regenerating boot/ocamlc with the compiler we just built" >&2
if make bootstrap >/tmp/ocaml-bootstrap.log 2>&1; then
  echo "OCAML-FIXPOINT: PASS — the shipped boot/ocamlc is a fixed point of this source tree" >&2
  echo "OCAML-FIXPOINT: NOTE this does NOT defeat Thompson; only the #48 ladder retires the blob" >&2
else
  echo "OCAML-FIXPOINT: MISMATCH or build error (non-fatal today; see tail) —" >&2
  tail -20 /tmp/ocaml-bootstrap.log >&2 || true
  echo "OCAML-FIXPOINT: a MISMATCH would mean the shipped blob does not reproduce from this source" >&2
fi


# ocamldebug mixes C + bytecode; exclude it from any blanket debug strip.
find "${OUTPUT_DIR}/usr/bin" -type f -executable ! -name 'ocamldebug' \
  | xargs strip --strip-unneeded 2>/dev/null || true
