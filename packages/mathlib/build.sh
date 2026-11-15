#!/bin/sh
# mathlib: the thin layer over mathlib-oleans (see build.ncl). No compile:
# check that the oleans were built from these exact sources, then install
# LEAN_PATH, MANIFEST, lake-manifest.json and every licence/notice. Seconds.
set -eu

ROOT="$(pwd)"
INFO=/usr/share/mathlib-oleans
LIBROOT=/usr/lib/lean/mathlib
cd leanprover-community-mathlib4-56a0058

# 1. Same Mathlib, same Lean, same Lake pins as the compile. A Mathlib tag
#    supports exactly one Lean, and these notices are only true of the code
#    mathlib-oleans compiled.
want="leanprover/lean4:v$(lean --version | sed -n 's/^Lean (version \([0-9.]*\).*/\1/p')"
have="$(cat lean-toolchain)"
if [ "$have" != "$want" ]; then
  echo "ERROR: mathlib lean-toolchain is '$have' but the lean we ship is '$want'." >&2
  echo "       Bump lean, mathlib-oleans, mathlib and aeneas-latest together (see build.ncl)." >&2
  exit 1
fi
same() { # what have-file want-file
  if [ "$(sha256sum < "$2")" != "$(sha256sum < "$3")" ]; then
    echo "mathlib: $1 differs from what mathlib-oleans was compiled from ($3); refusing to package." >&2
    echo "  The mathlib-oleans in this build is not the one these sources describe (e.g. a stale or" >&2
    echo "  patched artifact). Rebuild it from this tree: min package build --rebuild mathlib-oleans" >&2
    echo "  (~35 min on build-bot, longer locally; its build.sh sizes the job count to the box's memory)." >&2
    exit 1
  fi
}
printf 'mathlib-oleans %s\n' "$MINIMAL_ARG_VERSION" > "$ROOT/want-version"
same "version $MINIMAL_ARG_VERSION" "$ROOT/want-version" "$INFO/VERSION"
same lean-toolchain lean-toolchain "$INFO/lean-toolchain"
same lake-manifest.json lake-manifest.json "$INFO/lake-manifest.json"
# The widget bundles the ProofWidgets oleans embed (include_str) are the ones
# the notices below are pinned to.
PW="$ROOT/leanprover-community-ProofWidgets4-df72b02"
( cd "$PW/widget" &&
  LC_ALL=C sha256sum package-lock.json $(LC_ALL=C ls js/*.js) ) > "$ROOT/widget.sha256"
same "ProofWidgets widget/ (package-lock.json, js/*.js)" "$ROOT/widget.sha256" "$INFO/proofwidgets-widget.sha256"

# 2. Every Mathlib module has an .olean and an .ir in the installed tree
#    (mathlib-oleans checked each module's files at compile time; this
#    catches a truncated subset).
n_src=$(find Mathlib.lean Mathlib -name '*.lean' | wc -l)
for ext in olean ir; do
  n=$(find -L "$LIBROOT/mathlib/lib/Mathlib.$ext" "$LIBROOT/mathlib/lib/Mathlib" -name "*.$ext" 2>/dev/null | wc -l)
  if [ "$n" -ne "$n_src" ]; then
    echo "mathlib: $n_src Mathlib modules but $n .$ext files under $LIBROOT/mathlib; refusing to package." >&2
    echo "  mathlib-oleans' artifact is incomplete. Rebuild it: min package build --rebuild mathlib-oleans" >&2
    echo "  (~35 min on build-bot, longer locally; its build.sh sizes the job count to the box's memory)." >&2
    exit 1
  fi
done

# 3. LEAN_PATH (Mathlib first, then its dependencies in byte order),
#    lake-manifest.json, and a MANIFEST of what is installed, so a consumer
#    can tell a complete package from a truncated one. The order is
#    LC_ALL=C, not the sandbox locale's collation: the fv-lab loadout copies
#    this exact string. Sizes are summed file bytes, not `du` (block
#    allocation is not reproducible).
PKGS="$(cd "$LIBROOT" && for n in $(LC_ALL=C ls); do if [ -d "$n" ]; then echo "$n"; fi; done)"
LEAN_PATH_OUT="$LIBROOT/mathlib/lib"
for n in $PKGS; do
  [ "$n" = mathlib ] || LEAN_PATH_OUT="$LEAN_PATH_OUT:$LIBROOT/$n/lib"
done
SHARE="$OUTPUT_DIR/usr/share/mathlib"
mkdir -p "$SHARE"
printf '%s\n' "$LEAN_PATH_OUT" > "$SHARE/LEAN_PATH"
cp lake-manifest.json "$SHARE/"
{
  echo "mathlib $MINIMAL_ARG_VERSION"
  for n in $PKGS; do
    d="$LIBROOT/$n"
    echo "$n $(find -L "$d" -name '*.olean' | wc -l) oleans $(find -L "$d" -name '*.ir' | wc -l) ir $(find -L "$d" -type f -printf '%s\n' | awk '{s+=$1} END {printf "%d", s/1024}') KB"
  done
  echo "total files: $(find -L "$LIBROOT" -type f | wc -l)"
} > "$SHARE/MANIFEST"
cat "$SHARE/MANIFEST"

# 4. Licences and third-party notices: install-licences.sh, shared with
#    mathlib-oleans (both list it through notices.ncl), checks each notice
#    against the pinned ProofWidgets bundles and fails closed.
sh "$ROOT/install-licences.sh" "$ROOT" "$OUTPUT_DIR/usr/share/licenses/mathlib" \
  mathlib=. \
  plausible="$ROOT/leanprover-community-plausible-dfa4f38" \
  LeanSearchClient="$ROOT/leanprover-community-LeanSearchClient-d6b4c7b" \
  importGraph="$ROOT/leanprover-community-import-graph-a41f0e9" \
  proofwidgets="$PW" \
  aesop="$ROOT/leanprover-community-aesop-4a174c4" \
  Qq="$ROOT/leanprover-community-quote4-dce0ad7" \
  batteries="$ROOT/leanprover-community-batteries-66e4691" \
  Cli="$ROOT/leanprover-lean4-cli-c24fe60"
