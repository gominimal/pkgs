#!/bin/sh
set -ex

export BUILD_PATH_PREFIX_MAP="/builddir=$(pwd)"

# Absolute /usr layout; the findlib config lands at /usr/lib/findlib.conf and
# the site-lib under the ocaml stdlib dir so OCAMLPATH=/usr/lib/ocaml finds it.
./configure \
    -bindir /usr/bin \
    -mandir /usr/share/man \
    -sitelib /usr/lib/ocaml \
    -config /usr/lib/findlib.conf

make all
make opt
# The findlib Makefile installs to $(DESTDIR)$(prefix)<abs-path>, so DESTDIR
# alone redirects the absolute /usr paths into the sandbox output tree.
make install DESTDIR="$OUTPUT_DIR"
