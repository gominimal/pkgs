#!/bin/sh
set -eu

# The Source is extracted with strip_prefix: the tree is the cwd.

# Valgrind's memcheck intercepts strlen (amd64: also strcmp/memcmp) inside the
# dynamic linker from the first instruction, and finds them by SYMBOL NAME in
# ld.so's .symtab: they are not exported, so .dynsym does not have them. On a
# distro that strips ld.so every memcheck run aborts with "Fatal error at
# startup: a function redirection which is mandatory for this platform-tool
# combination cannot be set up" (README_PACKAGERS). Our glibc does not strip
# ld.so, so nothing extra is needed -- but nothing in glibc promises that
# either. This build sandbox mounts the same glibc the package runs against
# (it is a runtime dep), so fail the build here, before shipping a valgrind
# that cannot start, if a glibc change ever strips those symbols.
ldso=
for cand in /usr/lib/ld-linux-x86-64.so.2 /usr/lib/ld-linux-aarch64.so.1; do
  if [ -e "$cand" ]; then ldso=$cand; fi
done
if [ -z "$ldso" ]; then
  echo "valgrind: no ld-linux under /usr/lib" >&2
  exit 1
fi
case $(uname -m) in
  x86_64)  need="strlen strcmp memcmp" ;;
  *)       need="strlen" ;;
esac
# nm reads .symtab only (not .dynsym), exactly the table valgrind consults.
syms=$(nm "$ldso" | awk '{print $NF}')
for s in $need; do
  if ! printf '%s\n' "$syms" | grep -qx "$s"; then
    echo "valgrind: $ldso has no .symtab entry for '$s'; glibc ships a stripped ld.so and memcheck would abort at startup" >&2
    exit 1
  fi
done

# No -march / -O3: valgrind compiles its tools with its own per-platform flags
# on top of CFLAGS, and README_PACKAGERS asks for the symbols and debug info on
# libexec/valgrind/* and the vgpreload_*.so to stay (stack traces in valgrind's
# own errors, names of intercepted allocators). -g stays; the rest is the
# reproducibility set.
export CFLAGS="-g -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc

# --without-mpicc: the MPI wrapper library is optional and needs an MPI
# compiler we do not ship; configure would otherwise probe for one.
# --enable-only64bit: on amd64 configure would otherwise also try the 32-bit
# x86 secondary, which needs an -m32 multilib gcc/glibc we do not build.
./configure \
  --prefix=/usr \
  --enable-only64bit \
  --without-mpicc

make -j"$(nproc)"
make DESTDIR="$OUTPUT_DIR" install

# The annotate/diff/merge scripts start with `#! /usr/bin/env perl|python3`.
# Point them straight at the interpreters this package declares as runtime
# deps, so they need no coreutils for /usr/bin/env.
for f in "$OUTPUT_DIR"/usr/bin/*; do
  [ -f "$f" ] || continue
  case $(head -c 2 "$f") in
    '#!')
      sed -i \
        -e '1s|^#! */usr/bin/env perl$|#!/usr/bin/perl|' \
        -e '1s|^#! */usr/bin/env python3$|#!/usr/bin/python3|' \
        "$f"
      ;;
  esac
done
if grep -l '^#! */usr/bin/env' "$OUTPUT_DIR"/usr/bin/* 2>/dev/null; then
  echo "valgrind: a script still uses /usr/bin/env (listed above)" >&2
  exit 1
fi

# vgstack is a /bin/sh wrapper that drives gdb (and awk) against vgdb; shipping
# it would make gdb a runtime dep of every valgrind user. vgdb itself stays: it
# is the relay and needs no gdb. Users who want vgstack add gdb themselves.
rm -f "$OUTPUT_DIR/usr/bin/vgstack"

# HTML/PDF manuals; the man pages stay.
rm -rf "$OUTPUT_DIR/usr/share/doc"
