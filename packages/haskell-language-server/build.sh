#!/bin/bash
set -euo pipefail

# The source tarball is already extracted with strip_prefix, so we're in the source root

# cabal needs a writable HOME for its config, package index, and build store.
export CABAL_DIR="$PWD/.cabal-home"
mkdir -p "$CABAL_DIR"

# Build HLS for the GHC version available in the sandbox
export GHC="$(command -v ghc)"
export CABAL="$(command -v cabal)"

# GHC's shared libraries (libHSrts, etc.) aren't on the default library search
# path. Cabal installs alex/happy from Hackage as build-tool-depends; those
# binaries link against GHC's shared libs and fail to run without this —
# cabal reports "version could not be determined" (Cabal-1008). We let cabal
# install its own alex/happy (built with 9.10.3, so their template files land
# in the right data dir) rather than using the system alex/happy, which were
# built with ghc-bootstrap 9.8.1 and look for templates in the wrong dir.
GHC_LIBDIR="$(ghc --print-libdir)"
export LD_LIBRARY_PATH="${GHC_LIBDIR}:${LD_LIBRARY_PATH:-}"

# Update cabal package index
cabal update

# Build HLS with the available GHC version. The cabal.project ships with
# tests:True and benchmarks:True, which makes the solver consider test/benchmark
# deps for every transitive dependency — pass --disable-tests/--disable-benchmarks
# to build only the executable.
set +e
cabal build \
  --disable-tests \
  --disable-benchmarks \
  --with-compiler="$(command -v ghc)" \
  --jobs="$(nproc)" \
  -v1 \
  exe:haskell-language-server 2>&1 | tee /tmp/hls-build.log
rc=${PIPESTATUS[0]}
set -e
if [ "$rc" -ne 0 ]; then
    echo "===== cabal build failed (rc=$rc) — real error: ====="
    grep -iE "\.hs:[0-9]+:[0-9]+: error|error:\s*\[GHC|error:\s*\[Cabal|undefined reference|cannot find -l|panic|internal error|cannot satisfy|conflict|could not be determined|Failed to build" /tmp/hls-build.log | tail -25 \
        || echo "(no error text captured)"
    tail -25 /tmp/hls-build.log
    exit 1
fi

# Install to OUTPUT_DIR
mkdir -p "$OUTPUT_DIR"/usr/bin
mkdir -p "$OUTPUT_DIR"/usr/lib

# Find and copy the built binary from cabal's build directory
HLS_BIN=$(cabal list-bin exe:haskell-language-server)
cp "$HLS_BIN" "$OUTPUT_DIR"/usr/bin/

# Copy all shared Haskell libraries the binary depends on
for lib in $(ldd "$HLS_BIN" | grep '\.so' | awk '{print $3}'); do
  if [ -n "$lib" ] && [ -f "$lib" ]; then
    libname="${lib##*/}"
    # Only copy Haskell-specific libraries (libHS*) to avoid bundling standard system glibc/loader libraries
    if [[ "$libname" == libHS* ]]; then
      cp "$lib" "$OUTPUT_DIR"/usr/lib/
    fi
  fi
done
