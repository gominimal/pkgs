#!/bin/bash
set -euo pipefail

# Extract source
tar -xof "ghc-${MINIMAL_ARG_VERSION}-src.tar.xz"
cd "ghc-${MINIMAL_ARG_VERSION}"

# Patch hp2ps/Utilities.c for GCC 15 / C23 compatibility
sed -i 's/extern void\* malloc();/extern void\* malloc(long unsigned int);/' utils/hp2ps/Utilities.c
sed -i 's/extern void \*realloc();/extern void \*realloc(void \*, long unsigned int);/' utils/hp2ps/Utilities.c

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
python3 hadrian/bootstrap/bootstrap.py -w "$(command -v ghc)" --bootstrap-sources ../hadrian-bootstrap-sources-9.8.1.tar.gz

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
./configure \
  --prefix=/usr \
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