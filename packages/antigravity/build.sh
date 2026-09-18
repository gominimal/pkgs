#!/bin/sh
set -ex

# The tarball holds exactly one member — the `antigravity` binary — and the
# Source is declared extract=true, so it is already unpacked in the cwd.
if [ ! -f antigravity ]; then
  echo "expected an 'antigravity' binary from the extracted tarball" >&2
  exit 1
fi

# Drop the vestigial libresolv.so.2 dependency.
#
# The binary carries a DT_NEEDED on libresolv.so.2 but imports exactly ONE
# symbol from that family — __res_search — and since glibc 2.34 the resolver
# lives in libc.so.6; libresolv.so.2 survives only as an ABI-compat stub that
# exports nothing. glibc's own resolv/Versions confirms it: __res_search sits
# in the `libc {` block, not the `libresolv {` one.
#
# So the dependency is a lie the linker records and nothing needs. Removing it
# makes the ELF describe what the binary actually uses, and incidentally stops
# `missing runtime_deps` reporting a symbol as absent from a library that was
# never supposed to have it (gominimal/minimal#1548).
#
# This is only safe because __res_search is the sole resolver import — verified
# by reading the dynamic symbol table, where it is the one `res_`/`ns_`/`dn_`
# entry among 298 undefined symbols. The LD_BIND_NOW=1 smoketest is the guard:
# it forces the loader to bind every symbol at startup, so if __res_search were
# NOT resolvable from libc the package would fail its own test rather than
# ship something that dies on first DNS lookup.
patchelf --remove-needed libresolv.so.2 antigravity

mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 antigravity "$OUTPUT_DIR/usr/bin/antigravity"
