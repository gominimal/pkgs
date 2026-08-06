#!/bin/bash
set -euo pipefail

VERSION="$MINIMAL_ARG_VERSION"

build_setup() {
  # Determine setup file
  local setup_file="Setup.hs"
  if [ -f Setup.lhs ]; then
    setup_file="Setup.lhs"
  elif [ ! -f Setup.hs ]; then
    echo "import Distribution.Simple" > Setup.hs
    echo "main = defaultMain" >> Setup.hs
  fi
  ghc --make "$setup_file"
}

# happy 2.x splits the parser generator into happy-lib plus a thin executable, so
# happy-lib has to be built and registered into a build-local package database
# before the executable can be configured.
PKG_DB="$PWD/package.conf.d"
ghc-pkg init "$PKG_DB"

(
  cd "happy-lib-$VERSION"
  build_setup
  ./Setup configure --prefix=/usr --package-db="$PKG_DB"
  ./Setup build
  # Register the build tree rather than the install location: the templates are
  # already baked in with the /usr prefix from configure, but /usr/lib does not
  # exist yet while the executable is being linked.
  ./Setup register --inplace
  ./Setup copy --destdir="$PWD/../stage"
)

# Only happy-lib's templates are needed at runtime; its Haskell libraries are
# statically linked into the executable.
mkdir -p "$OUTPUT_DIR/usr"
cp -a stage/usr/share "$OUTPUT_DIR/usr/"

cd "happy-$VERSION"
build_setup
./Setup configure --prefix=/usr --package-db="$PKG_DB"
./Setup build
./Setup copy --destdir="$OUTPUT_DIR"
