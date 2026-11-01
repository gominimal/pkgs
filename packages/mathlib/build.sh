#!/bin/sh
# mathlib: build ALL of Mathlib from source, offline, for the lean we ship.
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
  echo "       Bump lean, mathlib and aeneas-latest together (see build.ncl)." >&2
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
#    thread cap). Eight is a memory decision, not a CPU one: the builders are
#    48 (arm64) and 96 (amd64) vCPU, but the box shares them with other
#    builds, and Mathlib's upstream CI reaches only ~15x parallelism on a full
#    build anyway (10.6 h of per-module time in 43 min wall, v4.35.0 bump PR).
export LEAN_NUM_THREADS=8
lake build Mathlib

# 5. Fail closed on an incomplete build: every Mathlib module must have its
#    .olean and the two sidecars lean refuses to load without. (`.ir` is
#    counted in the MANIFEST rather than asserted per module.)
LIB=.lake/build/lib/lean
missing=0
for f in Mathlib.lean $(find Mathlib -name '*.lean'); do
  m="${f%.lean}"
  for ext in olean olean.server olean.private; do
    if [ ! -f "$LIB/$m.$ext" ]; then
      echo "mathlib: missing $LIB/$m.$ext" >&2
      missing=$((missing + 1))
    fi
  done
done
if [ "$missing" -ne 0 ]; then
  echo "mathlib: $missing module files missing after lake build; refusing to package." >&2
  exit 1
fi

# 6. Install: one directory per Lake package, plus the LEAN_PATH a consumer
#    needs (Mathlib first, then its dependencies).
OUT="$OUTPUT_DIR/usr/lib/lean/pkgs"
LEAN_PATH_OUT=""
install_pkg() { # name srcdir
  mkdir -p "$OUT/$1/lib"
  cp -a "$2/.lake/build/lib/lean/." "$OUT/$1/lib/"
  LEAN_PATH_OUT="${LEAN_PATH_OUT:+$LEAN_PATH_OUT:}/usr/lib/lean/pkgs/$1/lib"
}
install_pkg mathlib .
for d in .lake/packages/*/; do
  n="$(basename "$d")"
  [ -d "$d/.lake/build/lib/lean" ] && install_pkg "$n" "$d"
done
# Lake's per-module build records are build-tree state, not library content.
find "$OUT" \( -name '*.trace' -o -name '*.hash' -o -name '*.log.json' \) -type f -delete

SHARE="$OUTPUT_DIR/usr/share/mathlib"
mkdir -p "$SHARE"
printf '%s\n' "$LEAN_PATH_OUT" > "$SHARE/LEAN_PATH"
cp lake-manifest.json "$SHARE/"
# What was installed, so a consumer can tell a complete package from a
# truncated one. Sizes are summed file bytes, not `du` (block allocation is
# not reproducible; see aeneas-latest).
{
  echo "mathlib $MINIMAL_ARG_VERSION"
  for d in "$OUT"/*/; do
    n="$(basename "$d")"
    echo "$n $(find "$d" -name '*.olean' | wc -l) oleans $(find "$d" -name '*.ir' | wc -l) ir $(find "$d" -type f -printf '%s\n' | awk '{s+=$1} END {printf "%d", s/1024}') KB"
  done
  echo "total files: $(find "$OUT" -type f | wc -l)"
} > "$SHARE/MANIFEST"
cat "$SHARE/MANIFEST"

# 7. Licences. The cache redistributes this package, so every upstream
#    licence travels with it (Apache-2.0 s4(a)/(d): a copy of the licence and
#    any NOTICE file; MIT: the copyright and permission notice). One directory
#    per source, named like the Lake package. None of the nine pinned sources
#    ships a NOTICE file today; one that appears is copied too.
LIC="$OUTPUT_DIR/usr/share/licenses/mathlib"
install_lic() { # name srcdir
  mkdir -p "$LIC/$1"
  cp "$2/LICENSE" "$LIC/$1/LICENSE"
  # `if`, not `[ … ] && cp`: with no NOTICE the && form returns 1 and
  # `set -e` would abort the build.
  for n in "$2"/NOTICE*; do
    if [ -f "$n" ]; then cp "$n" "$LIC/$1/"; fi
  done
}
install_lic mathlib .
for n in plausible LeanSearchClient importGraph proofwidgets aesop Qq batteries Cli; do
  install_lic "$n" ".lake/packages/$n"
done
# ProofWidgets' committed widget JS bundles npm code whose notices the
# minified files do not carry. Ship (a) the package/licence inventory and
# (b) the full third-party NOTICE (verbatim licence texts from the exact npm
# tarballs; regenerate with gen-proofwidgets-notice.py), both build.ncl
# Locals, and only if each was generated from THIS lockfile.
have_lock="$(sha256sum .lake/packages/proofwidgets/widget/package-lock.json | cut -d' ' -f1)"
install_pw_doc() { # local-file dest-name
  want_lock="$(sed -n 's/^package-lock.json sha256: //p' "$ROOT/$1")"
  if [ -z "$want_lock" ] || [ "$want_lock" != "$have_lock" ]; then
    echo "mathlib: $1 was generated from package-lock.json '$want_lock'," >&2
    echo "         but the pinned ProofWidgets has $have_lock. Regenerate it." >&2
    exit 1
  fi
  cp "$ROOT/$1" "$LIC/proofwidgets/$2"
}
install_pw_doc proofwidgets-js-third-party.txt THIRD-PARTY-JS.txt
install_pw_doc proofwidgets-js-NOTICE.txt THIRD-PARTY-NOTICES.txt

# Fail closed: every expected licence file is installed and non-empty, and
# each says what build.ncl's license_spdx claims (Apache-2.0, except
# lean4-cli's MIT).
for n in mathlib plausible LeanSearchClient importGraph proofwidgets aesop Qq batteries Cli; do
  f="$LIC/$n/LICENSE"
  if [ ! -s "$f" ]; then
    echo "mathlib: licence file $f missing or empty; refusing to package." >&2
    exit 1
  fi
  case "$n" in
    Cli) grep -q '^MIT License' "$f" ;;
    *)   grep -q 'Apache License' "$f" && grep -q 'Version 2.0, January 2004' "$f" ;;
  esac || { echo "mathlib: $f is not the licence build.ncl declares for $n." >&2; exit 1; }
done
test -s "$LIC/proofwidgets/THIRD-PARTY-JS.txt"
test -s "$LIC/proofwidgets/THIRD-PARTY-NOTICES.txt"
