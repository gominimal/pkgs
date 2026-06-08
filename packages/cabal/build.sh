#!/bin/bash
set -euo pipefail

# Patch monorepo .cabal files to accept GHC 9.10.1's built-in Cabal-syntax-3.12.0.0
# (cabal-install-3.12.1.0 expects ^>=3.12.1.0 but GHC 9.10.1 ships 3.12.0.0)
for cabal_file in \
    Cabal/Cabal.cabal \
    Cabal-syntax/Cabal-syntax.cabal \
    cabal-install-solver/cabal-install-solver.cabal \
    cabal-install/cabal-install.cabal; do
    if [ -f "$cabal_file" ]; then
        sed -i 's/Cabal-syntax\s*\^>=\s*3\.12\.1\.0/Cabal-syntax >= 3.12.0.0 \&\& < 3.13/g' "$cabal_file"
        sed -i 's/Cabal\s*\^>=\s*3\.12\.1\.0/Cabal >= 3.12.0.0 \&\& < 3.13/g' "$cabal_file"
    fi
done

# Offline bootstrap: use the pre-fetched hackage deps bundled at packaging
# time (cabal's own `bootstrap.py fetch` vs GHC 9.10.3, each dep sha-verified).
# The archive is a Source build_dep that hydrates next to the build dir;
# bootstrap.py unpacks its plan-bootstrap.json + tarballs and compiles
# cabal-install with ZERO network egress. (#51 Option B regenerates this on
# the fetcher so it never touches local bandwidth.)
BSRC=$(ls cabal-bootstrap-sources.tar.gz ../cabal-bootstrap-sources.tar.gz 2>/dev/null | head -1)
python3 bootstrap/bootstrap.py -w "$(command -v ghc)" -s "$BSRC"

# The bootstrap script compiles cabal-install and installs to _build/bin
mkdir -p "$OUTPUT_DIR"/usr/bin
cp -v _build/bin/cabal "$OUTPUT_DIR"/usr/bin/cabal

# Install man pages (may not exist in all versions)
mkdir -p "$OUTPUT_DIR"/usr/share/man/man1
cp -v doc/man/cabal.1 "$OUTPUT_DIR"/usr/share/man/man1/ 2>/dev/null || true

# Install documentation
mkdir -p "$OUTPUT_DIR"/usr/share/doc/cabal
cp -v README.md "$OUTPUT_DIR"/usr/share/doc/cabal/ 2>/dev/null || true
