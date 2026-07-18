#!/bin/bash
set -euo pipefail

# tamarin ships as a Stack project pinned to GHC 9.6 (LTS 22.x), but minimal has
# GHC 9.10.3. Its .cabal files carry NO upper version bounds, so we drive it with
# `cabal` + the system GHC and let cabal's solver pick 9.10-compatible dependency
# versions from Hackage. Pioneering — upstream has no published 9.10 build.

# Hackage fetches flake intermittently, but cabal already re-fetches on a TUF
# sha256 mismatch, falls back to mirrors, and retries each fetch internally, so
# we rely on that native resilience rather than a hand-rolled retry loop. The
# complete fix is a cabal.project.freeze + `--offline` (a bigger job) which
# drops the network dependency entirely. (The earlier "IncompleteRead" note
# was cargo-culted from cabal's Python bootstrap; tamarin's fetches go through
# cabal/ghc's Haskell HTTP stack, not Python.)

# cabal needs a writable HOME for its config, package index, and build store.
export CABAL_DIR="$PWD/.cabal-home"
mkdir -p "$CABAL_DIR"

# Fetch the Hackage package index.
cabal update

# Vendor a GHC-9.10-patched fclabels. Upstream 2.0.5.1 (dormant since 2021) is the
# ONE dep that doesn't compile on 9.10: its TH derivation hits the
# template-haskell 2.22 TyVarBndr flag change (() -> BndrVis) at Derive.hs:310.
# `cabal get` unpacks the hackage source; we patch it and add it as a LOCAL
# package so cabal builds the fixed copy instead of the broken hackage one.
# (pkgmgr-rs#528)
cabal get fclabels-2.0.5.1
patch -p1 -d fclabels-2.0.5.1 < fclabels-ghc910.patch
# fclabels 2.0.5.1's .cabal caps base/template-haskell/mtl/... below GHC 9.10's
# versions; our source patch makes it actually compile on 9.10, so strip the stale
# upper bounds (` && < X.Y`) so the solver accepts the installed 9.10.3 boot libs.
sed -i 's/ *&& *< *[0-9][0-9.]*//g' fclabels-2.0.5.1/fclabels.cabal

# Pin the whole dependency set to Stackage LTS 24.50 — the curated, mutually-
# compatible snapshot for GHC 9.10.3 (minimal's exact GHC). This is what makes the
# yesod/warp/wai web stack build: LTS 24 tested those versions together on 9.10.3,
# whereas an unconstrained `allow-newer: all` picks bleeding-edge combos that don't
# line up (e.g. yesod-static needs crypton 1.0.6 + memory 0.18.0, not the newest).
# Strip the config's `with-compiler:` (we pass --with-compiler on the CLI instead).
# The LTS config is fetched (extract=false Source) — see build.ncl.
grep -v '^with-compiler:' stackage-lts-24.50.cabal.config > lts-pinned.config
# tamarin is a multi-package project (stack.yaml, which cabal ignores) → declare
# the root + six lib sub-packages. fclabels was DROPPED from LTS 24 (doesn't build
# on 9.10 unpatched), so it isn't in the pin; our patched local copy provides it,
# and `allow-newer: fclabels` relaxes its stale upper bounds against the LTS libs.
{
  echo "import: lts-pinned.config"
  echo "packages: ./ ./lib/*/ ./fclabels-2.0.5.1"
} > cabal.project

# tamarin 1.12.0's Main/REPL.hs imports the record field `maudePath` by BARE name,
# which GHC 9.10 rejects (GHC-61689 — a field must be imported via its type). This
# is the REAL blocker (the earlier "link OOM" was a misdiagnosis: a parallel compile
# hid this error behind a truncated log). tamarin's develop branch already fixed
# this exact line; apply the same change — TheoryLoader exports TheoryLoadOptions(..),
# so the field is reachable via the type. (pkgmgr-rs#528)
sed -i 's/defaultTheoryLoadOptions, maudePath, TheoryLoadError/defaultTheoryLoadOptions, TheoryLoadOptions(maudePath), TheoryLoadError/' src/Main/REPL.hs

# Build + install the executable (STATIC — a normal Haskell static link; the link
# was never the problem). The sandbox hides build detail, so on failure dump the
# real error (compile OR link) rather than a silent "Failed to build".
set +e
cabal build exe:tamarin-prover \
    --with-compiler="$(command -v ghc)" \
    --jobs="$(nproc)" -v1 2>&1 | tee /tmp/tam-build.log
rc=${PIPESTATUS[0]}
set -e
if [ "$rc" -ne 0 ]; then
    echo "===== cabal build failed (rc=$rc) — real error: ====="
    grep -iE "\.hs:[0-9]+:[0-9]+: error|error:\s*\[GHC|undefined reference|cannot find -l|panic|internal error" /tmp/tam-build.log | tail -25 \
        || echo "(no error text captured)"
    tail -25 /tmp/tam-build.log
    exit 1
fi

mkdir -p "$OUTPUT_DIR/usr/bin"
cp -v "$(cabal list-bin exe:tamarin-prover)" "$OUTPUT_DIR/usr/bin/tamarin-prover"

# Smoke-test the binary. tamarin's `--version` probes for `maude` (its runtime
# backend — a runtime_dep, NOT present in the build sandbox), so it exits
# non-zero with "maude: ... does not exist" AFTER printing its own version
# banner. Capture the output, tolerate that expected non-zero, and assert the
# banner is present: that proves the executable itself is good without requiring
# maude at build time. (pkgmgr-rs#528)
ver_out="$("$OUTPUT_DIR/usr/bin/tamarin-prover" --version 2>&1 || true)"
echo "$ver_out"
# tamarin prints its banner as "... checking version: tamarin-prover 1.12.0 ..."
# (mid-line, then hard-errors on the missing maude), so match the version token
# anywhere rather than anchoring to line start.
echo "$ver_out" | grep -qE "tamarin-prover [0-9]+\.[0-9]" \
    || { echo "smoke test failed: tamarin-prover did not print its version banner" >&2; exit 1; }
echo "tamarin-prover built + smoke-tested OK (maude runtime probe skipped — it's a runtime_dep)"
