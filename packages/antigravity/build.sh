#!/bin/sh
set -ex

# The tarball holds exactly one member — the `antigravity` binary — and the
# Source is declared extract=true, so it is already unpacked in the cwd.
if [ ! -f antigravity ]; then
  echo "expected an 'antigravity' binary from the extracted tarball" >&2
  exit 1
fi

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

# Assert the rewrite actually happened. patchelf exits 0 when the soname it was
# told to replace is not present, so a future upstream build that drops the
# libresolv dependency on its own — or a typo in the soname above — would leave
# this script reporting success having changed nothing. Check the ELF instead of
# trusting the exit code.
needed=$(patchelf --print-needed antigravity)
if echo "$needed" | grep -q '^libresolv\.so\.2$'; then
  echo "antigravity: libresolv.so.2 is still in DT_NEEDED after --replace-needed" >&2
  exit 1
fi
if ! echo "$needed" | grep -q '^libc\.so\.6$'; then
  echo "antigravity: libc.so.6 is not in DT_NEEDED; the resolver symbol has nowhere to bind" >&2
  echo "$needed" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 antigravity "$OUTPUT_DIR/usr/bin/antigravity"
