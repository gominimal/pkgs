#!/bin/bash
set -euo pipefail

if [ ! -f Setup.hs ] && [ ! -f Setup.lhs ]; then
  echo "import Distribution.Simple" > Setup.hs
  echo "main = defaultMain" >> Setup.hs
fi

ghc --make Setup.hs
./Setup configure --prefix=/usr
./Setup build
./Setup copy --destdir="$OUTPUT_DIR"
