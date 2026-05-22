#!/bin/bash
set -euo pipefail

# Extract source
tar -xof "ghc-${MINIMAL_ARG_VERSION}-src.tar.xz"
cd "ghc-${MINIMAL_ARG_VERSION}"

# Patch hp2ps/Utilities.c for GCC 15 / C23 compatibility
sed -i 's/extern void\* malloc();/extern void\* malloc(long unsigned int);/' utils/hp2ps/Utilities.c
sed -i 's/extern void \*realloc();/extern void \*realloc(void \*, long unsigned int);/' utils/hp2ps/Utilities.c

# Detect architecture for bootstrap binary selection
BOOTSTRAP_ARCH="$(uname -m)"
case "$BOOTSTRAP_ARCH" in
  x86_64) BOOTSTRAP_TAR="ghc-9.8.2-x86_64-deb11-linux.tar.xz"; BOOTSTRAP_LIB_ARCH="x86_64-linux-ghc-9.8.2" ;;
  aarch64) BOOTSTRAP_TAR="ghc-9.8.2-aarch64-deb11-linux.tar.xz"; BOOTSTRAP_LIB_ARCH="aarch64-linux-ghc-9.8.2" ;;
  *) echo "Unsupported architecture: $BOOTSTRAP_ARCH"; exit 1 ;;
esac

# Extract bootstrap GHC source and install it properly
mkdir -p ../bootstrap-src
tar -xof "../${BOOTSTRAP_TAR}" -C ../bootstrap-src --strip-components=1
export BOOTSTRAP_DIR="$PWD/../bootstrap"
mkdir -p "$BOOTSTRAP_DIR"

# Configure and install the bootstrap GHC
(
  cd ../bootstrap-src
  ./configure --prefix="$BOOTSTRAP_DIR"
  make install_bin install_lib update_package_db
)

# To run the bootstrap GHC, we need to set LD_LIBRARY_PATH so it can find its own libraries
export LD_LIBRARY_PATH="$BOOTSTRAP_DIR/lib/${BOOTSTRAP_LIB_ARCH}"

# Ensure the bootstrap GHC and the build-produced tools (like alex/happy) are in PATH
export PATH="$BOOTSTRAP_DIR/bin:$PWD/_build/bin:$PATH"

# We also need a libtinfo.so.6, which GHC expects but we don't have. We can link it to the system libncursesw.so.6.
mkdir -p "$BOOTSTRAP_DIR/lib"
ln -sf /usr/lib/libncursesw.so.6 "$BOOTSTRAP_DIR/lib/libtinfo.so.6"
export LD_LIBRARY_PATH="$BOOTSTRAP_DIR/lib:$LD_LIBRARY_PATH"

# Modify bootstrap settings to use standard ld instead of ld.gold
if [ -f "$BOOTSTRAP_DIR/lib/settings" ]; then
  sed -i 's/-fuse-ld=gold//g' "$BOOTSTRAP_DIR/lib/settings"
  sed -i 's|/usr/bin/ld.gold|/usr/bin/ld|g' "$BOOTSTRAP_DIR/lib/settings"
fi

# Extract and build alex
mkdir -p ../alex-src
tar -xof ../alex-3.5.1.0.tar.gz -C ../alex-src --strip-components=1
(
  cd ../alex-src
  if [ ! -f Setup.hs ] && [ ! -f Setup.lhs ]; then
    echo "import Distribution.Simple" > Setup.hs
    echo "main = defaultMain" >> Setup.hs
  fi
  "$BOOTSTRAP_DIR/bin/ghc" --make Setup.hs
  ./Setup configure --prefix="$BOOTSTRAP_DIR"
  ./Setup build
  ./Setup install
)

# Extract and build happy
mkdir -p ../happy-src
tar -xof ../happy-1.20.1.1.tar.gz -C ../happy-src --strip-components=1
(
  cd ../happy-src
  if [ ! -f Setup.hs ] && [ ! -f Setup.lhs ]; then
    echo "import Distribution.Simple" > Setup.hs
    echo "main = defaultMain" >> Setup.hs
  fi
  "$BOOTSTRAP_DIR/bin/ghc" --make Setup.hs
  ./Setup configure --prefix="$BOOTSTRAP_DIR"
  ./Setup build
  ./Setup install
)

# Create stubs for tools ./configure checks for but aren't strictly needed
# hadrian bootstrap will download the real cabal via internet access
mkdir -p "$BOOTSTRAP_DIR/bin"

# Cabal stub - ./configure just checks it exists via AC_PATH_PROG(CABAL,cabal)
cat << 'EOF' > "$BOOTSTRAP_DIR/bin/cabal"
#!/bin/sh
exit 0
EOF
chmod +x "$BOOTSTRAP_DIR/bin/cabal"

# Sphinx stub - skip actual doc generation
cat << 'EOF' > "$BOOTSTRAP_DIR/bin/sphinx-build"
#!/bin/sh
if [ "$1" = "--version" ]; then
  echo "sphinx-build 4.0.0"
  exit 0
fi
exit 0
EOF
chmod +x "$BOOTSTRAP_DIR/bin/sphinx-build"

# Bootstrap Hadrian
python3 hadrian/bootstrap/bootstrap.py -w "$BOOTSTRAP_DIR/bin/ghc"

# Add pseudostore lib dirs to LD_LIBRARY_PATH so bootstrapped tools (like alex/happy) can find their dependencies
PSEUDO_LIBS="$(find _build/pseudostore -name "*.so*" -exec dirname {} \; | sort -u | paste -sd : || true)"
if [ -n "$PSEUDO_LIBS" ]; then
  export LD_LIBRARY_PATH="$PSEUDO_LIBS:$LD_LIBRARY_PATH"
fi

# Now we can configure GHC.
# Since alex/happy are now in _build/bin, configure will detect them correctly!
./configure \
  --prefix=/usr \
  GHC="$BOOTSTRAP_DIR/bin/ghc"

# Now we can run the build!
# GHC 9.10.1 uses Hadrian to build.
_build/bin/hadrian -j"$(nproc)" --flavour=quickest --docs=none

# And install!
DESTDIR=$OUTPUT_DIR _build/bin/hadrian install --prefix=/usr --docs=none
