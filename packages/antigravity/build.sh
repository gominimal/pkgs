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
# REPOINT the libresolv dependency at libc rather than removing it.
#
# --remove-needed does NOT work here: it drops DT_NEEDED but leaves the
# .gnu.version_r records still naming libresolv.so.2, and because __res_search
# is a VERSIONED symbol reference the loader then aborts before main with
#   "Inconsistency detected by ld.so: dl-version.c:204 ... Assertion
#    `needed != NULL' failed!"
#
# --replace-needed rewrites the soname in both DT_NEEDED and the version-needs
# records, so they stay consistent. Repointing at libc is correct rather than a
# trick: verified by parsing both libraries out of the sandbox —
#   libresolv.so.2  __res_search DEFINED? NO  (71 symbols, no resolver entry)
#   libc.so.6       __res_search DEFINED? YES
# glibc 2.34+ consolidated the resolver into libc and left libresolv as a stub,
# so libc is where the symbol actually lives.
#
# The LD_BIND_NOW=1 smoketest is the guard: it forces the loader to bind every
# symbol at startup, so a wrong soname fails the package's own test instead of
# shipping something that dies on first DNS lookup. It already caught the
# --remove-needed attempt.
patchelf --replace-needed libresolv.so.2 libc.so.6 antigravity

mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 antigravity "$OUTPUT_DIR/usr/bin/antigravity"
