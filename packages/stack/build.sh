#!/bin/bash
set -euo pipefail

if [ -f Setup.hs ]; then
  echo '{-# LANGUAGE CPP #-}' > Setup.hs.tmp
  while IFS= read -r line; do
    if [[ "$line" == *"import           Distribution.Utils.Path ( interpretSymbolicPathCWD )"* ]]; then
      echo "#if MIN_VERSION_Cabal(3,14,0)" >> Setup.hs.tmp
      echo "import           Distribution.Utils.Path ( interpretSymbolicPathCWD )" >> Setup.hs.tmp
      echo "#endif" >> Setup.hs.tmp
    elif [[ "$line" == *"main :: IO ()"* ]]; then
      echo "#if !MIN_VERSION_Cabal(3,14,0)" >> Setup.hs.tmp
      echo "interpretSymbolicPathCWD :: FilePath -> FilePath" >> Setup.hs.tmp
      echo "interpretSymbolicPathCWD = id" >> Setup.hs.tmp
      echo "#endif" >> Setup.hs.tmp
      echo "" >> Setup.hs.tmp
      echo "$line" >> Setup.hs.tmp
    else
      echo "$line" >> Setup.hs.tmp
    fi
  done < Setup.hs
  mv Setup.hs.tmp Setup.hs
fi

# NB: do NOT widen stack.cabal's Cabal bounds. stack 3.9.3's own code uses Cabal >=3.14
# APIs (Stack.Types.Component etc.), so building against ghc-9.10's boot Cabal-3.12.1.0
# fails to COMPILE with GHC-61689 (it got to [162 of 215] before dying). Widening the
# bound to accept 3.12 was the wrong lever. Instead the cabal cache ships a reinstallable
# Cabal-3.14.2.0 + Cabal-syntax-3.14.2.0 as library deps; the ORIGINAL `>=3.14` bound
# forces the solve onto 3.14.x. 3.14.2.0 is the unique sweet spot — it satisfies stack's
# `>=3.14 && <3.17` library need AND cabal-install's "<3.16 max Cabal for Setup.hs" cap
# (3.16 is rejected for setup, 3.12 fails stack's code). So: no stack.cabal edit needed.

if [ -f cabal.config ]; then
  sed -i '/unix ==/d' cabal.config
  sed -i '/Cabal ==/d' cabal.config
  sed -i '/Cabal-syntax ==/d' cabal.config
fi

# Hermetic offline path. cabal-v2 `--offline` does NOT consume source tarballs
# from a remote-repo-cache (it refuses present tarballs); the offline mechanism
# is a `file+noindex` local repository. The builder hydrates /cabal-cache as a
# FLAT repo: <pkg>-<ver>.tar.gz + the hackage-REVISED <pkg>-<ver>.cabal for
# stack's COMPLETE plan — the 183 build deps PLUS the ~43 test/benchmark/build-
# tool deps the solver needs *available* (e.g. vector's internal benchmarks-O2
# lib pulls tasty). That set is captured via `cabal freeze` against full hackage
# (cabal does the version-solving), then downloaded; they are never compiled.
# Point a sole file+noindex repo at a writable copy, `cabal update` (offline dir
# scan → noindex.cache), then build. Outside CS (no /cabal-cache) fall back
# online. --disable-tests/-benchmarks so the solver prunes them; -j4 caps peak
# RAM (cborg et al. are memory-hungry to compile).
if [ -d /cabal-cache ]; then
  REPO=/tmp/cabal-local-repo
  mkdir -p "$REPO"
  cp /cabal-cache/*.tar.gz /cabal-cache/*.cabal "$REPO"/ 2>/dev/null || cp -r /cabal-cache/* "$REPO"/
  export CABAL_DIR=/tmp/cabal-home
  mkdir -p "$CABAL_DIR"
  printf 'repository local-cache\n  url: file+noindex://%s\n' "$REPO" > "$CABAL_DIR/config"
  cabal update
  cabal build --disable-tests --disable-benchmarks -j4
else
  cabal update
  cabal build
fi

# Install stack binary
mkdir -p "$OUTPUT_DIR"/usr/bin
cp -v "$(cabal list-bin stack)" "$OUTPUT_DIR"/usr/bin/

# Install man pages
mkdir -p "$OUTPUT_DIR"/usr/share/man/man1
cp -v doc/man/stack.1 "$OUTPUT_DIR"/usr/share/man/man1/ 2>/dev/null || true

# Install documentation
mkdir -p "$OUTPUT_DIR"/usr/share/doc/stack
cp -v doc/README.md "$OUTPUT_DIR"/usr/share/doc/stack/ 2>/dev/null || true
