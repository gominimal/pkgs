#!/bin/sh
# Repack gcc's shared runtime libraries into a package of their own.
#
# A `subsetOf gcc [...]` runtime dep fetches all of gcc (~300 MB per arch) and
# pulls gcc's runtime_deps (gmp, mpc, mpfr, zlib, zstd) into every consumer's
# closure: minimal resolves a subset against the whole parent build
# (crates/graph transitives.rs; the remote cache is per build, not per output).
# Consumers that only load libgcc_s/libstdc++/... depend on this instead
# (gominimal/inbox#1261). The files are copied byte for byte from the gcc
# build dep, so they cannot drift from the compiler that links against them.
set -eu

. ./stage.sh

copy 'libgcc_s.so*'
copy 'libstdc++.so*'
copy 'libgomp.so*'
copy 'libatomic.so*'
copy 'libssp.so*'
case $(uname -m) in
  x86_64) copy 'libquadmath.so*' ;; # gcc builds libquadmath on amd64 only
esac

# Each SONAME a consumer records in DT_NEEDED must be present.
for so in libgcc_s.so.1 libstdc++.so.6 libgomp.so.1 libatomic.so.1 libssp.so.0; do
  [ -e "$dst/$so" ] || { echo "ERROR: $so missing from gcc-runtime" >&2; exit 1; }
done
one_real_file 'libstdc++.so.6.*' libstdc++.so.6
one_real_file 'libgomp.so.1.*' libgomp.so.1
one_real_file 'libatomic.so.1.*' libatomic.so.1
one_real_file 'libssp.so.0.*' libssp.so.0
