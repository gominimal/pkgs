#!/bin/bash
set -euo pipefail

# tamarin ships as a Stack project pinned to GHC 9.6 (LTS 22.x), but minimal has
# GHC 9.10.3. Its .cabal files carry NO upper version bounds, so we drive it with
# `cabal` + the system GHC and let cabal's solver pick 9.10-compatible dependency
# versions from Hackage. Pioneering — upstream has no published 9.10 build.

# Hackage fetches flake intermittently (truncated reads -> IncompleteRead); cabal
# re-fetches cleanly on a verified sha mismatch, so retry is safe (cf. cabal's
# build.sh, which hit the same).
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

# cabal needs a writable HOME for its config, package index, and build store.
export CABAL_DIR="$PWD/.cabal-home"
mkdir -p "$CABAL_DIR"

# Fetch the Hackage package index.
retry cabal update

# Vendor a GHC-9.10-patched fclabels. Upstream 2.0.5.1 (dormant since 2021) is the
# ONE dep that doesn't compile on 9.10: its TH derivation hits the
# template-haskell 2.22 TyVarBndr flag change (() -> BndrVis) at Derive.hs:310.
# `cabal get` unpacks the hackage source; we patch it and add it as a LOCAL
# package so cabal builds the fixed copy instead of the broken hackage one.
# (pkgmgr-rs#528)
retry cabal get fclabels-2.0.5.1
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

# Reproducibility: tamarin's version banner embeds the WALL-CLOCK compile time
#
#     Git revision: UNKNOWN, branch: UNKNOWN
#     Compiled at: 2026-07-25 03:47:54.541898723 UTC
#
# via a TemplateHaskell splice that calls getCurrentTime while COMPILING. It
# asks the clock directly, so the sandbox's SOURCE_DATE_EPOCH never reaches it,
# and two builds differ by exactly that string — measured: 26 bytes out of
# 135 MB, with the Haskell codegen itself bit-identical. (The git fields are
# already deterministic: no repo here, so both builds say UNKNOWN.)
#
# Rewrite the splice to a fixed instant derived from SOURCE_DATE_EPOCH. Located
# by content rather than by path so an upstream file move fails loudly here
# instead of silently reverting to a wall clock.
STAMP="$(date -u -d "@${SOURCE_DATE_EPOCH:-0}" '+%Y-%m-%d %H:%M:%S UTC' 2>/dev/null \
        || date -u -r "${SOURCE_DATE_EPOCH:-0}" '+%Y-%m-%d %H:%M:%S UTC')"
stamp_file="$(grep -rl 'Compiled at' --include='*.hs' src lib 2>/dev/null | head -1)"
if [ -z "$stamp_file" ]; then
    echo "ERROR: no source file embeds 'Compiled at' — tamarin's version banner moved; revisit this patch." >&2
    exit 1
fi
# Replace the compile-time-clock splice with the pinned literal. Upstream
# COMPOSES the action rather than naming it bare:
#     $(stringE =<< runIO (show `fmap` Data.Time.getCurrentTime))
# so the first pattern matches the whole parenthesised argument. The two bare
# forms are kept in case upstream simplifies back to them.
sed -i "s|runIO ([^)]*getCurrentTime[^)]*)|pure (\"$STAMP\")|g; \
        s|runIO Data\.Time\.getCurrentTime|pure (\"$STAMP\")|g; \
        s|runIO getCurrentTime|pure (\"$STAMP\")|g" "$stamp_file"
if grep -q 'getCurrentTime' "$stamp_file"; then
    echo "ERROR: tamarin compile-time-clock patch did not apply in $stamp_file (splice shape changed)." >&2
    grep -n 'getCurrentTime' "$stamp_file" >&2
    exit 1
fi

# ── amd64: use the PACKAGED alex/happy, not cabal's own ──────────────────────
#
# tamarin built on arm64 and failed on amd64 (pkgs#606's run, 2026-08-14) with:
#
#   Error: [Cabal-1008]
#   The program 'alex' version >=3.1.4 is required but the version of
#   /build/.cabal-home/store/ghc-9.10.3-inplace/alex-3.5.4.2-.../bin/alex
#   could not be determined.
#
# NOT a compile error: cabal BUILT alex fine ("Completed alex-3.5.4.2 (exe:alex)")
# and then could not get a version out of it when `language-javascript`
# configured. So the binary exists and will not answer — which is what you get
# from a partially-installed store entry under `--jobs=$(nproc)`, or from an
# invocation killed for memory. Either way it is cabal provisioning its own copy
# that fails, and both alex and happy are already packaged for both arches.
#
# Point cabal at those instead. `--with-PROG` is Cabal's documented override for
# a known program, and alex/happy are known programs.
#
# The assertions below are deliberate: if the packaged tools are the problem
# rather than the fix, this fails HERE with the version printed, instead of 40
# minutes later inside a dependency's configure step with no way to tell which
# alex cabal used. Amd64 could not be reproduced locally (this fleet develops on
# arm64), so the next run's log is the experiment.
ALEX_BIN="$(command -v alex)"
HAPPY_BIN="$(command -v happy)"
echo "tamarin: packaged alex  = ${ALEX_BIN:-<not on PATH>}"
echo "tamarin: packaged happy = ${HAPPY_BIN:-<not on PATH>}"
[ -n "$ALEX_BIN" ]  || { echo "ERROR: alex not on PATH — build_deps regression" >&2; exit 1; }
[ -n "$HAPPY_BIN" ] || { echo "ERROR: happy not on PATH — build_deps regression" >&2; exit 1; }
# Prove they RUN and report a version — the exact thing cabal could not do.
"$ALEX_BIN" --version  || { echo "ERROR: packaged alex cannot report a version"  >&2; exit 1; }
"$HAPPY_BIN" --version || { echo "ERROR: packaged happy cannot report a version" >&2; exit 1; }

# Build + install the executable (STATIC — a normal Haskell static link; the link
# was never the problem). The sandbox hides build detail, so on failure dump the
# real error (compile OR link) rather than a silent "Failed to build".
set +e
cabal build exe:tamarin-prover \
    --with-compiler="$(command -v ghc)" \
    --with-alex="$ALEX_BIN" \
    --with-happy="$HAPPY_BIN" \
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
