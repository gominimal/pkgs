#!/bin/sh
# mathlib-oleans: compile ALL of Mathlib from source, offline, for the lean we
# ship. Only the compile: licences, notices, LEAN_PATH and MANIFEST are the
# thin `mathlib` package's (see build.ncl), so editing them does not rebuild
# this.
#
# Offline-lake mechanism adapted from nixpkgs `pkgs/build-support/lake`
# (MIT License, Copyright (c) 2003-2026 Eelco Dolstra and the Nixpkgs/NixOS
# contributors): dependencies live in `.lake/packages/<name>` as pinned
# sources, `.lake/package-overrides.json` points lake at them, and the cloud
# cache / Reservoir lookups are disabled. Unlike aeneas-latest, nothing is
# fetched: no `lake exe cache get`.
set -eu
export HOME="$(pwd)/home"; mkdir -p "$HOME"
export LAKE_NO_CACHE=1
export RESERVOIR_API_URL=""
export MATHLIB_NO_CACHE_ON_UPDATE=1

ROOT="$(pwd)"
cd leanprover-community-mathlib4-56a0058

# 1. A Mathlib tag supports exactly one Lean. Refuse to compile it against
#    another rather than produce oleans that fail at import time.
want="leanprover/lean4:v$(lean --version | sed -n 's/^Lean (version \([0-9.]*\).*/\1/p')"
have="$(cat lean-toolchain)"
if [ "$have" != "$want" ]; then
  echo "ERROR: mathlib lean-toolchain is '$have' but the lean we ship is '$want'." >&2
  echo "       Bump lean, mathlib-oleans, mathlib and aeneas-latest together (see build.ncl)." >&2
  exit 1
fi

# 2. Vendored dependencies into place (Lake package name -> extracted top-dir).
#    Names are the `name` fields of Mathlib's lake-manifest.json.
mkdir -p .lake/packages
mv "$ROOT/leanprover-community-plausible-dfa4f38" ".lake/packages/plausible"
mv "$ROOT/leanprover-community-LeanSearchClient-d6b4c7b" ".lake/packages/LeanSearchClient"
mv "$ROOT/leanprover-community-import-graph-a41f0e9" ".lake/packages/importGraph"
mv "$ROOT/leanprover-community-ProofWidgets4-df72b02" ".lake/packages/proofwidgets"
mv "$ROOT/leanprover-community-aesop-4a174c4" ".lake/packages/aesop"
mv "$ROOT/leanprover-community-quote4-dce0ad7" ".lake/packages/Qq"
mv "$ROOT/leanprover-community-batteries-66e4691" ".lake/packages/batteries"
mv "$ROOT/leanprover-lean4-cli-c24fe60" ".lake/packages/Cli"

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

# 4. Build the `Mathlib` library (the default target; not Archive,
#    Counterexamples, MathlibTest or the scripts' executables).
#
#    Parallelism: Lake 4.35 has no jobs flag. Its build jobs are Lean tasks
#    on the lake process's thread pool, so LEAN_NUM_THREADS bounds how many
#    `lean` children run at once (and each child inherits it as its own
#    thread cap). It is the `lean_num_threads` build arg, set per arch in
#    build.ncl (32 amd64, 24 arm64) and sized by memory there. It changes
#    the wall time, not the bytes.
case "${MINIMAL_ARG_LEAN_NUM_THREADS:-}" in
  ''|*[!0-9]*|0*) echo "mathlib-oleans: lean_num_threads must be a positive integer, got '${MINIMAL_ARG_LEAN_NUM_THREADS:-}'." >&2; exit 1 ;;
esac
export LEAN_NUM_THREADS="$MINIMAL_ARG_LEAN_NUM_THREADS"
lake build Mathlib

# 5. Fail closed on an incomplete build: every Mathlib module must have its
#    .olean and the two sidecars lean refuses to load without. (`.ir` is
#    counted in `mathlib`'s MANIFEST rather than asserted per module.)
LIB=.lake/build/lib/lean
missing=0
for f in Mathlib.lean $(find Mathlib -name '*.lean'); do
  m="${f%.lean}"
  for ext in olean olean.server olean.private; do
    if [ ! -f "$LIB/$m.$ext" ]; then
      echo "mathlib-oleans: missing $LIB/$m.$ext" >&2
      missing=$((missing + 1))
    fi
  done
done
if [ "$missing" -ne 0 ]; then
  echo "mathlib-oleans: $missing module files missing after lake build; refusing to package." >&2
  exit 1
fi

# 6. Install: one directory per Lake package. The root is
#    usr/lib/lean/mathlib, NOT aeneas-latest's usr/lib/lean/pkgs: both ship
#    mathlib/batteries/aesop/..., and a closure holding both resolves a
#    conflict per file, which could pair one build's .olean with the other's
#    .olean.server/.olean.private/.ir. Disjoint roots keep each tree whole.
OUT="$OUTPUT_DIR/usr/lib/lean/mathlib"
install_pkg() { # name srcdir
  mkdir -p "$OUT/$1/lib"
  cp -a "$2/.lake/build/lib/lean/." "$OUT/$1/lib/"
}
install_pkg mathlib .
for d in .lake/packages/*/; do
  n="$(basename "$d")"
  if [ -d "$d/.lake/build/lib/lean" ]; then install_pkg "$n" "$d"; fi
done
# Lake's per-module build records are build-tree state, not library content.
find "$OUT" \( -name '*.trace' -o -name '*.hash' -o -name '*.log.json' \) -type f -delete

# 7. What this was compiled from, for `mathlib` to check its own sources
#    against (it ships the notices for these exact widget bundles and the
#    lake-manifest.json consumers compare their pins with).
INFO="$OUTPUT_DIR/usr/share/mathlib-oleans"
mkdir -p "$INFO"
printf 'mathlib-oleans %s\n' "$MINIMAL_ARG_VERSION" > "$INFO/VERSION"
cp lean-toolchain lake-manifest.json "$INFO/"
( cd .lake/packages/proofwidgets/widget &&
  LC_ALL=C sha256sum package-lock.json $(LC_ALL=C ls js/*.js) ) > "$INFO/proofwidgets-widget.sha256"
