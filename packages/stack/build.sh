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

if [ -f stack.cabal ]; then
  sed -i 's/Cabal >=3.14 \&\& <3.18/Cabal >=3.12 \&\& <3.18/g' stack.cabal
fi

if [ -f cabal.config ]; then
  sed -i '/unix ==/d' cabal.config
  sed -i '/Cabal ==/d' cabal.config
  sed -i '/Cabal-syntax ==/d' cabal.config
fi

# Hermetic offline path: the builder hydrates the cabal cache (hackage index
# + stack's full dep-closure source tarballs) at /cabal-cache. Copy it to a
# writable CABAL_DIR (cabal writes its config/package-db/logs), skip the live
# `cabal update` (the index is already present), and build offline. Outside CS
# (no /cabal-cache) fall back to the normal online path for dev iteration.
# -j4 caps parallel package builds: a few Haskell deps (cborg, …) are very
# memory-hungry to compile; -j4 keeps peak RAM in check on the build VM.
if [ -d /cabal-cache ]; then
  export CABAL_DIR=/tmp/cabal-home
  cp -r /cabal-cache "$CABAL_DIR"
  cabal build --offline -j4
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
