#!/bin/bash
set -euo pipefail

# Extract source
tar -xof "ghc-${MINIMAL_ARG_VERSION}-src.tar.xz"
cd "ghc-${MINIMAL_ARG_VERSION}"

# Patch hp2ps/Utilities.c for GCC 15 / C23 compatibility
sed -i 's/extern void\* malloc();/extern void\* malloc(long unsigned int);/' utils/hp2ps/Utilities.c
sed -i 's/extern void \*realloc();/extern void \*realloc(void \*, long unsigned int);/' utils/hp2ps/Utilities.c

# Reproducibility: GHC iterates package/UnitId collections in hash-set order,
# making the linker arg / DT_NEEDED / .dynstr order in every binary AND the
# ghc-pkg package.cache non-deterministic. Code (.text/.rodata) is already
# byte-identical; this is pure ORDERING. Sort the two collections.
#
# (1) Link order — backport of upstream GHC #26838 / MR !15453 (merged for
#     10.0.1; NOT in 9.10.x; Debian ships this exact patch for 9.10.3). Restores
#     the sorted-by-UnitId order GHC <= 9.6 had.
ghc_state=compiler/GHC/Unit/State.hs
grep -q 'import Data.List ( intersperse, partition, sortBy, isSuffixOf, sortOn )' "$ghc_state" \
  && grep -q 'let preload1 = nonDetKeysUniqMap (filterUniqMap (isJust . uv_explicit) vis_map)' "$ghc_state" \
  || { echo "ERROR: GHC link-order patch targets not found in $ghc_state — GHC source changed; revisit the #26838 backport." >&2; exit 1; }
sed -i 's/import Data.List ( intersperse, partition, sortBy, isSuffixOf, sortOn )/import Data.List ( intersperse, partition, sortBy, isSuffixOf, sortOn, sort )/' "$ghc_state"
sed -i 's/let preload1 = nonDetKeysUniqMap (filterUniqMap (isJust . uv_explicit) vis_map)/let preload1 = sort $ nonDetKeysUniqMap (filterUniqMap (isJust . uv_explicit) vis_map)/' "$ghc_state"

# (2) ghc-pkg package.cache — sort the .conf list before it is read + serialized
#     so the post-build `ghc-pkg recache` emits a byte-identical cache regardless
#     of filesystem readdir order. (No upstream fix exists; `sort` already
#     imported in Main.hs.)
ghc_pkg_main=utils/ghc-pkg/Main.hs
grep -q 'confs = map (path </>) $ filter (".conf" `isSuffixOf`) fs' "$ghc_pkg_main" \
  || { echo "ERROR: ghc-pkg package.cache patch target not found in $ghc_pkg_main — GHC source changed." >&2; exit 1; }
# The `sort $` below needs `sort` in scope; 9.10.3's Main.hs imports it (line 78),
# but guard it so a future GHC import reorg fails here, not deep in the build.
grep -qE 'import Data.List \(.*\bsort\b' "$ghc_pkg_main" \
  || { echo "ERROR: 'sort' not imported in $ghc_pkg_main — patch (2) requires it (add a sort import)." >&2; exit 1; }
sed -i 's#confs = map (path </>) $ filter (".conf" `isSuffixOf`) fs#confs = map (path </>) $ sort $ filter (".conf" `isSuffixOf`) fs#' "$ghc_pkg_main"

# Create stubs for tools ./configure / bootstrap.py checks for but aren't strictly needed
STUB_DIR="$PWD/../stub-bin"
mkdir -p "$STUB_DIR"

# Cabal stub - ./configure just checks it exists via AC_PATH_PROG(CABAL,cabal)
cat << 'EOF' > "$STUB_DIR/cabal"
#!/bin/sh
exit 0
EOF
chmod +x "$STUB_DIR/cabal"

# Sphinx stub - skip actual doc generation
cat << 'EOF' > "$STUB_DIR/sphinx-build"
#!/bin/sh
if [ "$1" = "--version" ]; then
  echo "sphinx-build 4.0.0"
  exit 0
fi
exit 0
EOF
chmod +x "$STUB_DIR/sphinx-build"

# Ensure stubs and build-produced tools are in PATH
export PATH="$STUB_DIR:$PWD/_build/bin:$PATH"

# Bootstrap Hadrian
# We must explicitly pass the bootstrap GHC path and also pass --bootstrap-sources to force
# the bootstrap.py script to use the local offline tarballs instead of downloading them.
# Locate the bootstrap sources by GLOB rather than repeating the version. The
# version already lives in build.ncl's url + sha256; naming it a third time here
# is what broke the 9.14.1 bump (build.ncl moved to 9.12.2, this line stayed at
# 9.8.1, and bootstrap.py died on a missing file). Fail loudly if the glob is
# not exactly one file, so an ambiguous /build never silently picks the wrong
# bootstrap plan.
bootstrap_sources=(../hadrian-bootstrap-sources-*.tar.gz)
[ "${#bootstrap_sources[@]}" -eq 1 ] && [ -f "${bootstrap_sources[0]}" ] || {
  echo "ERROR: expected exactly one ../hadrian-bootstrap-sources-*.tar.gz, got: ${bootstrap_sources[*]}" >&2
  exit 1
}
python3 hadrian/bootstrap/bootstrap.py -w "$(command -v ghc)" --bootstrap-sources "${bootstrap_sources[0]}"

# Add pseudostore lib dirs to LD_LIBRARY_PATH so bootstrapped tools can find their dependencies
PSEUDO_LIBS="$(find _build/pseudostore -name "*.so*" -exec dirname {} \; | sort -u | paste -sd : || true)"
if [ -n "$PSEUDO_LIBS" ]; then
  if [ -n "${LD_LIBRARY_PATH:-}" ]; then
    export LD_LIBRARY_PATH="$PSEUDO_LIBS:$LD_LIBRARY_PATH"
  else
    export LD_LIBRARY_PATH="$PSEUDO_LIBS"
  fi
fi

# Now we can configure GHC.
#
# --with-system-libffi: use the libffi package we already declare as a
# runtime_dep instead of the copy bundled in libffi-tarballs/. Two reasons:
#
#  1. It makes the declared dependency true. ghc lists libffi in runtime_deps,
#     so the shipped compiler is expected to link the system libffi — but
#     without this flag the build compiled GHC's own bundled copy, and the
#     dependency described something that wasn't happening.
#
#  2. It is what unblocks 9.14.1. hadrian's `libffiContext` builds libffi
#     dynamic only when getLibraryWays contains Dynamic; --flavour=quickest
#     sets libraryWays = [vanilla], so libffi is built static-only. The RTS
#     rule (hadrian/src/Rules/Rts.hs) nevertheless asks for libffi.so and dies:
#
#       Needed "_build/stage1/rts/build/libffi.so" which is not any of
#       libffi's built shared libraries: []
#
#     needRtsLibffiTargets short-circuits on `useSystemFfi -> return []`, so
#     with this flag hadrian never reaches copyLibffiDynamicUnix at all.
./configure \
  --prefix=/usr \
  --with-system-libffi \
  GHC=ghc

# Now we can run the build!
_build/bin/hadrian -j"$(nproc)" --flavour=quickest --docs=none

# And install!
DESTDIR=$OUTPUT_DIR _build/bin/hadrian install --prefix=/usr --docs=none

# Refresh the package database cache so downstream builds don't see stale cache warnings
GHC_PKG="$(find "$OUTPUT_DIR" -name ghc-pkg -type f | head -1)"
if [ -n "$GHC_PKG" ]; then
    "$GHC_PKG" recache
fi