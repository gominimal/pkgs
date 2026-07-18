#!/bin/bash
set -euo pipefail

# cabal's bootstrap fetches ~20 tarballs from hackage.haskell.org live during the
# build. cabal/hackage-security already re-fetch on a TUF sha256 mismatch and
# fall back to mirrors on failure, and bootstrap.py retries each fetch a few
# times internally, so we rely on that native resilience rather than a
# hand-rolled retry loop. The complete fix is to build fully offline via
# `bootstrap.py ... fetch` + `--bootstrap-sources` (see packages/ghc, which uses
# the identical flag from the same forked script); that drops the network
# dependency (and `needs = { internet }`) entirely.

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

# Generate a bootstrap JSON that matches the actual GHC in the sandbox
python3 update_bootstrap_json.py bootstrap/linux-9.8.2.json > bootstrap/linux-actual.json

# Run the bootstrap script with the generated JSON
python3 bootstrap/bootstrap.py -w "$(command -v ghc)" -d bootstrap/linux-actual.json

# The bootstrap script compiles cabal-install and installs to _build/bin
mkdir -p "$OUTPUT_DIR"/usr/bin
cp -v _build/bin/cabal "$OUTPUT_DIR"/usr/bin/cabal

# Install man pages (may not exist in all versions)
mkdir -p "$OUTPUT_DIR"/usr/share/man/man1
cp -v doc/man/cabal.1 "$OUTPUT_DIR"/usr/share/man/man1/ 2>/dev/null || true

# Install documentation
mkdir -p "$OUTPUT_DIR"/usr/share/doc/cabal
cp -v README.md "$OUTPUT_DIR"/usr/share/doc/cabal/ 2>/dev/null || true
