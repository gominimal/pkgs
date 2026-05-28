#!/bin/bash
set -euo pipefail

cd "happy-$MINIMAL_ARG_VERSION"

# Determine setup file
SETUP_FILE="Setup.hs"
if [ -f Setup.lhs ]; then
  SETUP_FILE="Setup.lhs"
elif [ ! -f Setup.hs ]; then
  echo "import Distribution.Simple" > Setup.hs
  echo "main = defaultMain" >> Setup.hs
  SETUP_FILE="Setup.hs"
fi

ghc --make "$SETUP_FILE"
./Setup configure --prefix=/usr
./Setup build
./Setup copy --destdir="$OUTPUT_DIR"
