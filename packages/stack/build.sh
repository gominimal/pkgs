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

# Pin cabal index-state to the release date of stack 3.9.3
# to ensure build reproducibility and prevent dependency version drift.
echo "index-state: 2026-02-20T00:00:00Z" > cabal.project.local

cabal update
cabal build

# Install stack binary
mkdir -p "$OUTPUT_DIR"/usr/bin
cp -v "$(cabal list-bin stack)" "$OUTPUT_DIR"/usr/bin/

# Install man pages
mkdir -p "$OUTPUT_DIR"/usr/share/man/man1
cp -v doc/man/stack.1 "$OUTPUT_DIR"/usr/share/man/man1/ 2>/dev/null || true

# Install documentation
mkdir -p "$OUTPUT_DIR"/usr/share/doc/stack
cp -v doc/README.md "$OUTPUT_DIR"/usr/share/doc/stack/ 2>/dev/null || true
