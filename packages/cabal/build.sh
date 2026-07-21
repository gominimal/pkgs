#!/bin/bash
set -euo pipefail

# cabal's bootstrap fetches ~20 tarballs from hackage.haskell.org live during
# the build, and those downloads flake intermittently (truncated reads ->
# http.client.IncompleteRead). cabal verifies each tarball's sha256, so a
# partial download is re-fetched cleanly, which makes a retry safe. The
# hermetic fix is to vendor the bootstrap sources offline (see packages/ghc,
# which passes --bootstrap-sources) -- this retry is the cheap stopgap.
retry() {
    local -i attempt=1 max=4
    until "$@"; do
        if (( attempt >= max )); then
            echo "retry: '$*' failed after $max attempts" >&2
            return 1
        fi
        echo "retry: '$*' failed (attempt $attempt/$max) -- likely a transient hackage fetch; retrying in $(( attempt * 15 ))s" >&2
        sleep $(( attempt * 15 ))
        attempt+=1
    done
}

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

# Generate a bootstrap JSON that matches the actual GHC in the sandbox.
#
# The base plan is picked by cabal's OWN bootstrap/ directory, which ships a
# fixed set of linux-<ghc>.json files per cabal release — it does NOT track the
# GHC we build with. cabal 3.18.1.0 ships 9.6.7 / 9.8.4 / 9.10.3 / 9.12.4; the
# 9.8.2 this used to name existed only in older cabals, so bumping cabal broke
# it with a bare FileNotFoundError from our own script.
#
# Which one matters less than it looks: update_bootstrap_json.py REPLACES the
# `builtin` list with the real `ghc-pkg list` output, so the compiler-package
# half adapts to whatever GHC is on PATH. The base plan supplies the
# `dependencies` (Hackage packages to build), so take the newest available.
BOOTSTRAP_PLAN=bootstrap/linux-9.12.4.json
[ -f "$BOOTSTRAP_PLAN" ] || {
  echo "ERROR: $BOOTSTRAP_PLAN not found — cabal $(basename "$PWD") ships a different set of bootstrap plans." >&2
  echo "Available:" >&2
  ls bootstrap/linux-*.json >&2 || echo "  (none)" >&2
  echo "Pick the newest and update BOOTSTRAP_PLAN in build.sh." >&2
  exit 1
}
python3 update_bootstrap_json.py "$BOOTSTRAP_PLAN" > bootstrap/linux-actual.json

# Run the bootstrap script with the generated JSON
retry python3 bootstrap/bootstrap.py -w "$(command -v ghc)" -d bootstrap/linux-actual.json

# The bootstrap script compiles cabal-install and installs to _build/bin
mkdir -p "$OUTPUT_DIR"/usr/bin
cp -v _build/bin/cabal "$OUTPUT_DIR"/usr/bin/cabal

# Install man pages (may not exist in all versions)
mkdir -p "$OUTPUT_DIR"/usr/share/man/man1
cp -v doc/man/cabal.1 "$OUTPUT_DIR"/usr/share/man/man1/ 2>/dev/null || true

# Install documentation
mkdir -p "$OUTPUT_DIR"/usr/share/doc/cabal
cp -v README.md "$OUTPUT_DIR"/usr/share/doc/cabal/ 2>/dev/null || true
