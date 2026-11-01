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

# The boot compiler is ocaml-5.5.2's bytecode ocamlc/ocamllex (gen-11 of gominimal/bootstrap),
# not the tarball's shipped boot/ocamlc, which is deleted here. Same release, so the stock
# bootstrap applies unchanged.
BOOT=/usr/lib/ocaml-5.5.2/bin
[ -s "$BOOT/ocamlc.byte" ] && [ -s "$BOOT/ocamllex.byte" ] || { echo "ocaml: boot compiler missing at $BOOT" >&2; exit 1; }
rm -f boot/ocamlc boot/ocamllex
cp "$BOOT/ocamlc.byte" boot/ocamlc; cp "$BOOT/ocamllex.byte" boot/ocamllex; chmod 0755 boot/ocamlc boot/ocamllex
tail -c 12 boot/ocamlc | grep -q 'Caml1999X' || { echo "ocaml: boot ocamlc is not bytecode" >&2; exit 1; }

# world.opt = bytecode world + native (ocamlopt) compilers; no host OCaml, no network.
make -j"$(nproc)" world.opt
make install DESTDIR="$OUTPUT_DIR"

# ocamldebug mixes C + bytecode; exclude it from any blanket debug strip.
find "${OUTPUT_DIR}/usr/bin" -type f -executable ! -name 'ocamldebug' \
  | xargs strip --strip-unneeded 2>/dev/null || true
