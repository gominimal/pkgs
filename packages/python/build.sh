#!/bin/sh
set -e

tar -xof "Python-${MINIMAL_ARG_VERSION}.tar.xz"
cd "Python-${MINIMAL_ARG_VERSION}"

# CVE-2025-15367 (poplib command injection, gh-143923) -- cherry-picked from main;
# upstream never backported it to 3.14, so 3.14.10 still lacks it. Applied before
# configure so a failed hunk fails the build under `set -e` rather than quietly
# producing an unpatched poplib; -F0 refuses fuzzy hunks so a context drift on a
# later bump fails too, instead of landing the check somewhere else. The patch
# lives one level up because we extracted into a subdirectory above.
#
# Earlier backports ship upstream and were dropped on the bump that first carried
# them: gh-155999, gh-155694, gh-156002, gh-155292 in 3.14.8; gh-157265 (tarfile),
# gh-157579 (tempfile) and the CVE-2026-111943 ensurepip pip swap (gh-159894, pip
# 26.2.2) in 3.14.9. Each is listed in that release's own Misc/NEWS.
patch -Np1 -F0 -i "../0003-gh-143923-poplib-reject-control-characters.patch"

# OpenSSL 4 support for _ssl (python/cpython#149783, Modules/ only; see build.ncl).
# Same -F0 rule: a context drift fails the build instead of landing elsewhere.
patch -Np1 -F0 -i "../0004-gh-148292-openssl-4-support.patch"
grep -q '_ssl_data_40.h' Modules/_ssl.c

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
# -fno-semantic-interposition: drops PLT indirection on internal libpython calls
# — a deterministic perf win for --enable-shared that --enable-optimizations used
# to add implicitly. Re-added by hand since we drop --enable-optimizations below.
export CFLAGS="$MARCH -O3 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir -fno-semantic-interposition"
export LDFLAGS="-Wl,--build-id=none -fno-semantic-interposition"
export CXXFLAGS="${CFLAGS}"

# Reproducibility (two parts):
#  - libffi pin: make configure resolve MODULE__CTYPES_LDFLAGS deterministically
#    ('-lffi') instead of letting PKG_CHECK_MODULES non-deterministically pick
#    -L/usr/lib/../lib64 vs ../lib (which leaks into _sysconfigdata*.py/.json).
#  - drop PGO: --enable-optimizations runs a gcc PGO training pass whose .gcda
#    counters are NOT reproducible. Measured: building instrumented once and
#    running `-m test --pgo` twice, 216 of 334 .gcda differ (64%) — across the
#    core interpreter/parser/compiler, and some even differ in size (different
#    functions execute run-to-run), even with the hash seed pinned. No gcc flag
#    fixes the training DATA, and the workload can't be pinned without a stored
#    profile. Dropping it makes .text byte-identical; -fno-semantic-interposition
#    above recovers the main deterministic perf the flag had bundled.
#    (NOTE: --with-lto=full is also NOT deterministic here — WHOPR partitioning
#    perturbs libpython layout build-to-build; use -flto=1 if LTO perf is wanted.)
./configure  --prefix=/usr          \
            --enable-shared         \
            --with-system-expat     \
            --without-static-libpython \
            LIBFFI_CFLAGS="-I/usr/include" \
            LIBFFI_LIBS="-lffi"

make -j$(nproc)
# TODO
#make test TESTOPTS="--timeout 120"
make DESTDIR=$OUTPUT_DIR install

# CVE-2026-111943, after install: the pip that ensurepip put into site-packages
# must not vendor a CA bundle containing emSign ECC
# Root CA - G3. The needle is one line of that root's base64 PEM body (its public
# key), so it matches regardless of certifi's comment headers. 3.14.9 bundles
# pip 26.2.2 (fixed); this keeps a future bump from shipping an older pip.
PIP_CACERT="$(ls "$OUTPUT_DIR"/usr/lib/python3.*/site-packages/pip/_vendor/certifi/cacert.pem)"
[ -s "$PIP_CACERT" ] || {
  echo "python: ensurepip installed no pip/_vendor/certifi/cacert.pem" >&2
  exit 1
}
ls -d "$OUTPUT_DIR"/usr/lib/python3.*/site-packages/pip-*.dist-info >/dev/null || {
  echo "python: ensurepip installed no pip into site-packages" >&2
  exit 1
}
if grep -q 'djAQBgcqhkjOPQIBBgUrgQQAIgNiAAQjpQy4LRL1KPOxst3iAhKAnjlfSU2fySU0' "$PIP_CACERT"; then
  echo "python: bundled pip's certifi still trusts emSign ECC Root CA - G3 (CVE-2026-111943)" >&2
  exit 1
fi
