#!/bin/sh
set -e

tar -xof "Python-${MINIMAL_ARG_VERSION}.tar.xz"
cd "Python-${MINIMAL_ARG_VERSION}"

# CVE-2026-87910 (PSF-2026-40, gh-157265) -- see the patch header and the note in
# build.ncl. Applied before configure so a failed hunk fails the build under
# `set -e` rather than quietly producing a python whose tarfile link fallback still
# ignores a filter's None. The patch lives one level up because we extracted into
# a subdirectory above.
#
# Four earlier backports (gh-155999 tarfile, gh-155694 urllib, gh-156002 zipfile,
# gh-155292 stringprep) first ship in 3.14.8 and were dropped on that bump:
# 3.14.8's own Misc/NEWS lists all four, and each patch reported "previously
# applied" against the 3.14.8 tree. gh-157265 is NOT in that changelog and its
# patch still applies cleanly, so it stays.
patch -Np1 -i "../0002-gh-157265-tarfile-honor-filter-none-link-fallback.patch"

# CVE-2025-15367 (poplib command injection, gh-143923) -- cherry-picked from main;
# upstream never backported it to 3.14, so 3.14.8 still lacks it. Same fail-closed
# placement as 0002.
patch -Np1 -i "../0003-gh-143923-poplib-reject-control-characters.patch"

# CVE-2026-12345 (TemporaryDirectory cleanup race, gh-157579) -- upstream's own
# 3.14 backport, merged after 3.14.8 was cut. Same fail-closed placement.
patch -Np1 -i "../0004-gh-157579-tempfile-cleanup-race.patch"
# CVE-2026-111943 -- see the note on the pip wheel Source in build.ncl. Replace
# the pip wheel ensurepip bundles (26.2.1, whose vendored certifi still trusts
# the distrusted emSign ECC Root CA - G3) with ${MINIMAL_ARG_BUNDLED_PIP_VERSION},
# and point `_PIP_VERSION` at it: ensurepip opens
# `_bundled/pip-${_PIP_VERSION}-py3-none-any.whl` by exact name, so the wheel and
# the constant have to move together. Every step fails closed: exactly one old
# wheel must be there to remove, and the constant must read the new version
# afterwards, so a future 3.14.x that already bundles a newer pip fails here
# (time to drop this) instead of silently shipping two wheels or neither.
BUNDLED="Lib/ensurepip/_bundled"
OLD_PIP_WHEELS="$(ls "$BUNDLED"/pip-*.whl)"
[ "$OLD_PIP_WHEELS" = "$BUNDLED/pip-26.2.1-py3-none-any.whl" ] || {
  echo "python: expected ensurepip to bundle exactly pip 26.2.1, found: $OLD_PIP_WHEELS" >&2
  exit 1
}
rm "$OLD_PIP_WHEELS"
cp "../pip-${MINIMAL_ARG_BUNDLED_PIP_VERSION}-py3-none-any.whl" "$BUNDLED/"
sed -i 's/^_PIP_VERSION = "26\.2\.1"$/_PIP_VERSION = "'"${MINIMAL_ARG_BUNDLED_PIP_VERSION}"'"/' Lib/ensurepip/__init__.py
grep -qx "_PIP_VERSION = \"${MINIMAL_ARG_BUNDLED_PIP_VERSION}\"" Lib/ensurepip/__init__.py || {
  echo "python: failed to set ensurepip _PIP_VERSION to ${MINIMAL_ARG_BUNDLED_PIP_VERSION}" >&2
  exit 1
}

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
# must be the replacement, and its vendored CA bundle must not contain emSign ECC
# Root CA - G3. The needle is one line of that root's base64 PEM body (its public
# key), so it matches regardless of certifi's comment headers. This is what
# guards the shipped tree; the wheel swap above only guards the input.
PIP_CACERT="$(ls "$OUTPUT_DIR"/usr/lib/python3.*/site-packages/pip/_vendor/certifi/cacert.pem)"
[ -s "$PIP_CACERT" ] || {
  echo "python: ensurepip installed no pip/_vendor/certifi/cacert.pem" >&2
  exit 1
}
ls -d "$OUTPUT_DIR"/usr/lib/python3.*/site-packages/pip-"${MINIMAL_ARG_BUNDLED_PIP_VERSION}".dist-info >/dev/null || {
  echo "python: site-packages pip is not ${MINIMAL_ARG_BUNDLED_PIP_VERSION}" >&2
  exit 1
}
if grep -q 'djAQBgcqhkjOPQIBBgUrgQQAIgNiAAQjpQy4LRL1KPOxst3iAhKAnjlfSU2fySU0' "$PIP_CACERT"; then
  echo "python: bundled pip's certifi still trusts emSign ECC Root CA - G3 (CVE-2026-111943)" >&2
  exit 1
fi
