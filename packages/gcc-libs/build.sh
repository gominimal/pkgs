#!/usr/bin/bash
set -euo pipefail

# Copy gcc's target runtime libraries out of the build sandbox. The sandbox merges every input's
# files into one /usr, so this copies gcc-owned names only (never glibc's libc.so, libm.so, ...)
# and fails closed if what it finds is not the gcc this package declares (build_args.version).

want="${MINIMAL_ARG_VERSION:?build_args.version (gcc's version) is not set}"

have="$(gcc -dumpfullversion)"
if [ "$have" != "$want" ]; then
  echo "gcc-libs: sandbox gcc is $have, expected $want (gcc's upstream_version)" >&2
  exit 1
fi

# The C++ headers directory is versioned exactly; a second gcc (e.g. a cycle-breaker prebuilt of
# another release) in the sandbox would show up as a second libstdc++.so.6.0.* below.
if [ ! -d "/usr/include/c++/$want" ]; then
  echo "gcc-libs: /usr/include/c++/$want missing: the sandbox gcc is not $want" >&2
  exit 1
fi

shopt -s nullglob
stdcxx=(/usr/lib/libstdc++.so.6.0.*[0-9])
if [ "${#stdcxx[@]}" -ne 1 ]; then
  echo "gcc-libs: expected exactly one libstdc++.so.6.0.N, found: ${stdcxx[*]:-none}" >&2
  exit 1
fi
real="$(readlink -f /usr/lib/libstdc++.so.6)"
if [ "$real" != "${stdcxx[0]}" ] || [ ! -f "$real" ]; then
  echo "gcc-libs: /usr/lib/libstdc++.so.6 resolves to '$real', not ${stdcxx[0]}" >&2
  exit 1
fi

out="$OUTPUT_DIR/usr/lib"
mkdir -p "$out"

# Every top-level library gcc installs into /usr/lib (gcc/build.sh: --libdir=/usr/lib). Sanitizer
# and fortran runtimes are included when this gcc build has them; .la files are dropped.
for f in \
  /usr/lib/libgcc_s.so* \
  /usr/lib/libstdc++* \
  /usr/lib/libsupc++.a \
  /usr/lib/libatomic.* \
  /usr/lib/libgomp.* \
  /usr/lib/libitm.* \
  /usr/lib/libquadmath.* \
  /usr/lib/libssp* \
  /usr/lib/libgfortran.* \
  /usr/lib/libasan* \
  /usr/lib/libhwasan* \
  /usr/lib/liblsan* \
  /usr/lib/libtsan* \
  /usr/lib/libubsan* \
  /usr/lib/libsanitizer.spec \
  /usr/lib/libcc1.so*; do
  case "$f" in
    *.la) continue ;;
  esac
  cp -a "$f" "$out/"
done

# crtbegin*/crtend*.o, libgcc.a, libgcc_eh.a, libgcov.a (gcc's private tree).
if [ -d /usr/lib/gcc ]; then
  cp -a /usr/lib/gcc "$out/"
fi

for required in libgcc_s.so.1 libstdc++.so.6 libatomic.so.1 libgomp.so.1; do
  test -e "$out/$required" || { echo "gcc-libs: $required missing" >&2; exit 1; }
done
