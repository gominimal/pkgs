#!/bin/sh
# aeneas-latest: build the Aeneas Lean library (+ its pinned Mathlib closure)
# for the lean we ship.
#
# Offline-lake mechanism adapted from nixpkgs `pkgs/build-support/lake`
# (MIT License, Copyright (c) 2003-2026 Eelco Dolstra and the Nixpkgs/NixOS
# contributors): dependencies live in `.lake/packages/<name>` as pinned
# sources, `.lake/package-overrides.json` points lake at them, and the cloud
# cache / Reservoir lookups are disabled. Only Mathlib's build cache is
# fetched, and only the closure Aeneas imports.
set -eu
export HOME="$(pwd)/home"; mkdir -p "$HOME"
export LAKE_NO_CACHE=1
export RESERVOIR_API_URL=""
# Aeneas's lakefile precompiles `AeneasMeta` into a dynlib unless CI is set;
# interpreted is fine for checking models and needs no C toolchain here.
export CI=1
# leanc links via gcc here (there is no clang in the box).
export LEAN_CC=gcc
export CC=gcc

ROOT="$(pwd)"
cd AeneasVerif-aeneas-505b6ca/backends/lean

# 1. Our Lean 4.33 port, then the manifest that pins the deps we vendor.
patch -p1 < "$ROOT/aeneas-lean-4.33.patch"
cp "$ROOT/lake-manifest.json" lake-manifest.json

# 2. Vendored dependencies into place (name -> extracted top-dir).
mkdir -p .lake/packages
mv "$ROOT/leanprover-community-mathlib4-db584cd" ".lake/packages/mathlib"
mv "$ROOT/leanprover-community-plausible-b7eb330" ".lake/packages/plausible"
mv "$ROOT/leanprover-community-LeanSearchClient-5f4d51b" ".lake/packages/LeanSearchClient"
mv "$ROOT/leanprover-community-import-graph-16f02aa" ".lake/packages/importGraph"
mv "$ROOT/leanprover-community-ProofWidgets4-4be2e3d" ".lake/packages/proofwidgets"
mv "$ROOT/leanprover-community-aesop-3448c0b" ".lake/packages/aesop"
mv "$ROOT/leanprover-community-quote4-92c15be" ".lake/packages/Qq"
mv "$ROOT/leanprover-community-batteries-4488d40" ".lake/packages/batteries"
mv "$ROOT/leanprover-lean4-cli-6130a47" ".lake/packages/Cli"

# 3. The on-disk overrides file: lake resolves every `require` to these dirs.
{
  printf '{"schemaVersion":"1.2.0","packages":['
  first=1
  for d in .lake/packages/*/; do
    n="$(basename "$d")"
    [ "$first" = 1 ] || printf ','
    first=0
    printf '{"type":"path","name":"%s","inherited":false,"dir":".lake/packages/%s"}' "$n" "$n"
  done
  printf ']}'
} > .lake/package-overrides.json

# 4. Mathlib's prebuilt oleans — ONLY the closure Aeneas imports (28 modules).
#    Content-addressed files: the same inputs fetch the same bytes.
lake exe cache get Mathlib.Algebra.Algebra.ZMod Mathlib.Algebra.Group.Basic Mathlib.Algebra.Order.Ring.Canonical Mathlib.Algebra.Order.Sub.Basic Mathlib.Algebra.Order.Sub.Defs Mathlib.Control.Monad.Cont Mathlib.Data.BitVec Mathlib.Data.Fin.Basic Mathlib.Data.Int.Cast.Basic Mathlib.Data.Int.Init Mathlib.Data.List.GetD Mathlib.Data.Nat.Basic Mathlib.Data.Nat.Bitwise Mathlib.Data.Nat.Cast.Basic Mathlib.Data.Nat.Log Mathlib.Data.ZMod.Basic Mathlib.Order.Basic Mathlib.RingTheory.Int.Basic Mathlib.Tactic.Attr.Register Mathlib.Tactic.Basic Mathlib.Tactic.Core Mathlib.Tactic.DefEqTransformations Mathlib.Tactic.Linarith Mathlib.Tactic.OfNat Mathlib.Tactic.Ring Mathlib.Tactic.Ring.RingNF Mathlib.Tactic.Simproc.ExistsAndEq Mathlib.Tactic.Tauto

# 5. Build the library against them.
# Bound memory: the sandbox container is SIGKILLed when six `lean` jobs each
# hold a Mathlib-heavy import graph. Two jobs, two threads each, fit.
export LEAN_NUM_THREADS=2
LEAN_NUM_THREADS=2 lake build Aeneas

# 6. Install: oleans per Lake package under a dot-free path, plus the
#    LEAN_PATH a consumer needs (in dependency order, Aeneas first).
OUT="$OUTPUT_DIR/usr/lib/lean/pkgs"
LEAN_PATH_OUT=""
install_pkg() { # name srcdir
  mkdir -p "$OUT/$1/lib"
  cp -a "$2/.lake/build/lib/lean/." "$OUT/$1/lib/"
  LEAN_PATH_OUT="${LEAN_PATH_OUT:+$LEAN_PATH_OUT:}/usr/lib/lean/pkgs/$1/lib"
}
install_pkg aeneas .
for d in .lake/packages/*/; do
  n="$(basename "$d")"
  [ -d "$d/.lake/build/lib/lean" ] && install_pkg "$n" "$d"
done
printf '%s\n' "$LEAN_PATH_OUT" > "$OUT/LEAN_PATH"

mkdir -p "$OUTPUT_DIR/usr/share/aeneas-latest"
cp "$ROOT/aeneas-lean-4.33.patch" "$ROOT/lake-manifest.json" "$OUTPUT_DIR/usr/share/aeneas-latest/"
# Build manifest: what was installed (the per-package olean counts), so a
# consumer can tell a complete package from a truncated one at a glance.
{ echo "aeneas-latest $MINIMAL_ARG_VERSION"; for d in "$OUT"/*/; do n="$(basename "$d")"; echo "$n $(find "$d" -name "*.olean" | wc -l) oleans $(du -sk "$d" | cut -f1) KB"; done; echo "total files: $(find "$OUT" -type f | wc -l)"; } > "$OUTPUT_DIR/usr/share/aeneas-latest/MANIFEST"
