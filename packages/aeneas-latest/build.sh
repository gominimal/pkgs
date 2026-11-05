#!/bin/sh
# aeneas-latest: build the Aeneas Lean library for the lean we ship, against
# the `mathlib` package's installed oleans.
#
# No lake, no network. Mathlib (and batteries, aesop, Qq, ...) come prebuilt
# from the `mathlib` runtime dep (runtime deps are in the build too): its
# runtime dep `mathlib-oleans` compiled them
# from sha256-pinned sources (under /usr/lib/lean/mathlib), and `mathlib`
# itself ships /usr/share/mathlib/{LEAN_PATH,MANIFEST,lake-manifest.json}.
# Lake cannot reuse those oleans: it decides "up to date" from the
# per-module `.trace` files, which `mathlib-oleans` deliberately does not install,
# and with no trace it rebuilds the whole dependency (~30 min, and into a
# read-only tree). Dropping `require mathlib` does not help either: Lake 4.35
# runs every `lean` with LEAN_PATH set to the empty string and resolves
# imports only from workspace packages. So the ~270 Aeneas modules are
# compiled with plain `lean` in dependency order, the way lake would, with
# make doing the ordering: `lean --deps-json` parses each header and
# make builds an olean once every local import's olean exists.
set -eu
export HOME="$(pwd)/home"; mkdir -p "$HOME"

ROOT="$(pwd)"
MATHLIB_SHARE=/usr/share/mathlib
cd AeneasVerif-aeneas-ab34bd2/backends/lean

# 1. The lean we ship must be the one upstream targets. Refuse otherwise,
#    rather than produce oleans that fail at import time.
want="leanprover/lean4:v$(lean --version | sed -n 's/^Lean (version \([0-9.]*\).*/\1/p')"
have="$(cat lean-toolchain)"
if [ "$have" != "$want" ]; then
  echo "ERROR: aeneas lean-toolchain is '$have' but the lean we ship is '$want'." >&2
  echo "       Bump lean, mathlib-oleans, mathlib and aeneas-latest together (see build.ncl)." >&2
  exit 1
fi

# 2. The `mathlib` package must be the Mathlib this Aeneas commit pins:
#    Mathlib at the tag Aeneas requires, and every other Lake dependency at
#    the revision recorded in the pinned Aeneas source's own
#    lake-manifest.json (read from the tarball, not the build.ncl Local).
#    Mathlib's manifest is the one `mathlib` installs.
#
#    The Local copy is what pkgmgr reads for Aeneas's Lean version when it
#    checks a lean bump (data/toolchain_constraints.toml), so it must stay
#    verbatim upstream: refuse a tarball bump that left it behind.
if ! cmp -s lake-manifest.json "$ROOT/lake-manifest.json"; then
  echo "ERROR: packages/aeneas-latest/lake-manifest.json differs from the pinned aeneas source's" >&2
  echo "       backends/lean/lake-manifest.json. Copy that file from the aeneas commit in build.ncl" >&2
  echo "       into packages/aeneas-latest/ (pkgmgr reads it for Aeneas's Lean version)." >&2
  exit 1
fi
mathlib_tag="v$(sed -n '1s/^mathlib //p' "$MATHLIB_SHARE/MANIFEST")"
aeneas_tag="$(jq -r '.packages[] | select(.name == "mathlib") | .inputRev' lake-manifest.json)"
if [ "$aeneas_tag" != "$mathlib_tag" ]; then
  echo "ERROR: aeneas requires mathlib '$aeneas_tag' but the mathlib package is '$mathlib_tag'." >&2
  echo "       Move the aeneas pin in build.ncl to a commit that requires $mathlib_tag, or bump" >&2
  echo "       mathlib-oleans and mathlib to $aeneas_tag (with lean; see build.ncl)." >&2
  exit 1
fi
pins() { jq -r '.packages[] | select(.name != "mathlib") | "\(.name) \(.rev)"' "$1" | LC_ALL=C sort; }
pins lake-manifest.json > aeneas.pins
pins "$MATHLIB_SHARE/lake-manifest.json" > mathlib.pins
if ! cmp -s aeneas.pins mathlib.pins; then
  echo "ERROR: aeneas and the mathlib package pin different Lake dependencies:" >&2
  diff aeneas.pins mathlib.pins >&2 || true
  echo "       Move the aeneas pin in build.ncl to a commit whose lake-manifest.json matches" >&2
  echo "       Mathlib $mathlib_tag's, or re-pin mathlib-oleans/sources.ncl to Aeneas's revisions." >&2
  exit 1
fi

# 3. One make rule per source module: `build/lib/A/B.olean` depends on
#    `A/B.lean` and on the olean of each import that is a file here. Imports
#    that are not (Init, Lean, Std, Mathlib, ...) resolve through LEAN_PATH.
LC_ALL=C find . -path ./.lake -prune -o -name '*.lean' -print \
  | sed 's|^\./||' | grep -v '^lakefile\.lean$' | LC_ALL=C sort > modules.txt
# shellcheck disable=SC2046 # one argument per file, no spaces in these paths
lean --deps-json $(cat modules.txt) > deps.json
jq -r '.imports[] | (.errors // []) as $e | if ($e | length) > 0 then "!" + ($e | join("; ")) else [(.result // .["result?"]).imports[].module] | join(" ") end' \
  deps.json > imports.txt
if [ "$(wc -l < modules.txt)" -ne "$(wc -l < imports.txt)" ]; then
  echo "ERROR: lean --deps-json returned a different number of results than files." >&2
  exit 1
fi
{
  # A tab-indented recipe; printf keeps the tab literal.
  printf 'LEANFLAGS := -R . -Dweak.linter.dupNamespace=false\n'
  printf 'build/lib/%%.olean: %%.lean\n'
  printf '\t@mkdir -p $(@D)\n'
  printf '\t@echo "lean $<"\n'
  printf '\t@lean $(LEANFLAGS) -o $@ -i $(@:.olean=.ilean) $<\n'
  paste -d '|' modules.txt imports.txt | while IFS='|' read -r f imps; do
    case "$imps" in
      '!'*) echo "ERROR: cannot parse the header of $f: ${imps#!}" >&2; exit 1 ;;
    esac
    printf 'build/lib/%s.olean:' "${f%.lean}"
    for m in $imps; do
      p="$(printf '%s' "$m" | tr . /)"
      if [ -f "$p.lean" ]; then printf ' build/lib/%s.olean' "$p"; fi
    done
    printf '\n'
  done
} > Makefile
# Upstream's lakefile (lean_lib «Aeneas» {}, package leanOptions
# weak.linter.dupNamespace=false) is what LEANFLAGS mirrors; fail if it
# changes the option LEANFLAGS copies or grows build options this recipe
# does not reproduce. A lakefile.toml would be a new format: fail on that too.
if [ ! -f lakefile.lean ] || [ -e lakefile.toml ]; then
  echo "ERROR: upstream backends/lean no longer has exactly a lakefile.lean; re-derive LEANFLAGS" >&2
  echo "       in build.sh from its new lakefile, then update this check." >&2
  exit 1
fi
want_opts='  leanOptions := #[⟨`weak.linter.dupNamespace, false⟩]'
have_opts="$(grep 'leanOptions' lakefile.lean || true)"
if [ "$have_opts" != "$want_opts" ]; then
  echo "ERROR: upstream lakefile.lean's leanOptions is now:" >&2
  echo "$have_opts" >&2
  echo "       Mirror it in the Makefile's LEANFLAGS above (-D<option>=<value> each), then update want_opts." >&2
  exit 1
fi
for opt in moreLeanArgs moreServerOptions buildType platformIndependent; do
  if grep -q "$opt" lakefile.lean; then
    echo "ERROR: upstream lakefile.lean now sets '$opt'; mirror it in the Makefile's LEANFLAGS above, then drop" >&2
    echo "       '$opt' from this list." >&2
    exit 1
  fi
done

# 4. Build the `Aeneas` closure (what `lake build Aeneas` built).
# Bound memory: the sandbox container is SIGKILLed when six `lean` jobs each
# hold a Mathlib-heavy import graph. Two jobs, two threads each, fit.
LEAN_PATH="$(pwd)/build/lib:$(cat "$MATHLIB_SHARE/LEAN_PATH")"
export LEAN_PATH
export LEAN_NUM_THREADS=2
make -j2 build/lib/Aeneas.olean

# 5. Fail closed on an incomplete build: every module in the closure has its
#    .olean, the two sidecars lean refuses to load without, and its .ir.
n=0
for f in $(cd build/lib && find . -name '*.olean' | sed 's|^\./||'); do
  m="build/lib/${f%.olean}"
  for ext in olean.server olean.private ir; do
    if [ ! -f "$m.$ext" ]; then
      echo "aeneas-latest: missing $m.$ext" >&2
      exit 1
    fi
  done
  n=$((n + 1))
done
echo "aeneas-latest: built $n Aeneas modules"

# 6. Install Aeneas's own oleans, and a LEAN_PATH that a consumer reads:
#    Aeneas first, then the mathlib package's entries.
OUT="$OUTPUT_DIR/usr/lib/lean/pkgs"
mkdir -p "$OUT/aeneas/lib"
cp -a build/lib/. "$OUT/aeneas/lib/"
printf '/usr/lib/lean/pkgs/aeneas/lib:%s\n' "$(cat "$MATHLIB_SHARE/LEAN_PATH")" > "$OUT/LEAN_PATH"
echo "LEAN_PATH: $(cat "$OUT/LEAN_PATH")"

mkdir -p "$OUTPUT_DIR/usr/share/aeneas-latest"
cp lake-manifest.json "$OUTPUT_DIR/usr/share/aeneas-latest/"
# Build manifest: what was installed, so a consumer can tell a complete
# package from a truncated one at a glance. Sizes are summed file bytes, not
# `du -sk`: disk usage depends on block allocation and differed by 8 KB
# between two builds with identical files (2026-10 prod-pair diff).
{
  echo "aeneas-latest $MINIMAL_ARG_VERSION"
  echo "aeneas $(find "$OUT/aeneas" -name '*.olean' | wc -l) oleans $(find "$OUT/aeneas" -type f -printf '%s\n' | awk '{s+=$1} END {printf "%d", s/1024}') KB"
  echo "total files: $(find "$OUT" -type f | wc -l)"
  echo "mathlib: $(sed -n 1p "$MATHLIB_SHARE/MANIFEST") (the mathlib package)"
} > "$OUTPUT_DIR/usr/share/aeneas-latest/MANIFEST"
cat "$OUTPUT_DIR/usr/share/aeneas-latest/MANIFEST"
