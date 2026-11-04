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

# 2. Every Mathlib module has an .olean in the installed tree (mathlib-oleans
#    checked its sidecars at compile time; this catches a truncated subset).
n_src=$(find Mathlib.lean Mathlib -name '*.lean' | wc -l)
n_olean=$(find -L "$LIBROOT/mathlib/lib/Mathlib.olean" "$LIBROOT/mathlib/lib/Mathlib" -name '*.olean' 2>/dev/null | wc -l)
if [ "$n_olean" -ne "$n_src" ]; then
  echo "mathlib: $n_src Mathlib modules but $n_olean oleans under $LIBROOT/mathlib; refusing to package." >&2
  exit 1
fi

# 3. LEAN_PATH (Mathlib first, then its dependencies), lake-manifest.json,
#    and a MANIFEST of what is installed, so a consumer can tell a complete
#    package from a truncated one. Sizes are summed file bytes, not `du`
#    (block allocation is not reproducible; see aeneas-latest).
LEAN_PATH_OUT="$LIBROOT/mathlib/lib"
for d in "$LIBROOT"/*/; do
  n="$(basename "$d")"
  [ "$n" = mathlib ] || LEAN_PATH_OUT="$LEAN_PATH_OUT:$LIBROOT/$n/lib"
done
SHARE="$OUTPUT_DIR/usr/share/mathlib"
mkdir -p "$SHARE"
printf '%s\n' "$LEAN_PATH_OUT" > "$SHARE/LEAN_PATH"
cp lake-manifest.json "$SHARE/"
{
  echo "mathlib $MINIMAL_ARG_VERSION"
  for d in "$LIBROOT"/*/; do
    n="$(basename "$d")"
    echo "$n $(find -L "$d" -name '*.olean' | wc -l) oleans $(find -L "$d" -name '*.ir' | wc -l) ir $(find -L "$d" -type f -printf '%s\n' | awk '{s+=$1} END {printf "%d", s/1024}') KB"
  done
  echo "total files: $(find -L "$LIBROOT" -type f | wc -l)"
} > "$SHARE/MANIFEST"
cat "$SHARE/MANIFEST"

# 4. Licences. The cache redistributes this package, so every upstream
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
install_lic plausible "$ROOT/leanprover-community-plausible-dfa4f38"
install_lic LeanSearchClient "$ROOT/leanprover-community-LeanSearchClient-d6b4c7b"
install_lic importGraph "$ROOT/leanprover-community-import-graph-a41f0e9"
install_lic proofwidgets "$ROOT/leanprover-community-ProofWidgets4-df72b02"
install_lic aesop "$ROOT/leanprover-community-aesop-4a174c4"
install_lic Qq "$ROOT/leanprover-community-quote4-dce0ad7"
install_lic batteries "$ROOT/leanprover-community-batteries-66e4691"
install_lic Cli "$ROOT/leanprover-lean4-cli-c24fe60"
# ProofWidgets' committed widget JS bundles npm code whose notices the
# minified files do not carry. Ship (a) the package/licence inventory and
# (b) the full third-party NOTICE (verbatim licence texts from the exact npm
# tarballs; regenerate with gen-proofwidgets-notice.py), both build.ncl
# Locals, and only if each was generated from THIS lockfile.
have_lock="$(sha256sum "$PW/widget/package-lock.json" | cut -d' ' -f1)"
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

# Two of those bundles also embed a WebAssembly build of Graphviz (EPL-2.0,
# CPL-1.0 vpsc) plus expat and the Emscripten runtime, compiled into
# @hpcc-js/wasm's `wasmBinary`. The npm-derived NOTICE cannot see inside it,
# so proofwidgets-wasm-NOTICE.txt carries those licences and the EPL/CPL
# source offer. It was checked against these exact bundles; refuse to package
# if either changed (a ProofWidgets bump must re-check the Graphviz version).
#
# penroseCanvas.js and penroseDisplay.js embed @penrose/optimizer's Rust
# WebAssembly; proofwidgets-penrose-wasm-NOTICE.txt (generated by
# gen-proofwidgets-wasm-notice.py, which fails if any crate compiled into it
# lacks a licence text) carries every crate's notice. Same hash pin.
pin_wasm_notice() { # notice-file bundle...
  notice="$1"; shift
  for js in "$@"; do
    want="$(sed -n "s/^$js sha256: //p" "$ROOT/$notice")"
    have="$(sha256sum "$PW/widget/js/$js" | cut -d' ' -f1)"
    if [ -z "$want" ] || [ "$want" != "$have" ]; then
      echo "mathlib: $notice was checked against $js '$want'," >&2
      echo "         but the pinned ProofWidgets has $have. Re-check its WASM notices." >&2
      exit 1
    fi
  done
}
pin_wasm_notice proofwidgets-wasm-NOTICE.txt graphvizDisplay.js index.js
pin_wasm_notice proofwidgets-penrose-wasm-NOTICE.txt penroseCanvas.js penroseDisplay.js
# Fail closed on WebAssembly no notice covers: every bundle that embeds a
# wasm module (base64 `\0asm` header, an Emscripten `wasmBinary`, or any
# WebAssembly use) must be pinned by one of the two notices above.
for f in "$PW"/widget/js/*.js; do
  js="$(basename "$f")"
  if grep -qE 'AGFzbQ|wasmBinary|WebAssembly' "$f" &&
     ! grep -q "^$js sha256: " "$ROOT/proofwidgets-wasm-NOTICE.txt" "$ROOT/proofwidgets-penrose-wasm-NOTICE.txt"; then
    echo "mathlib: widget/js/$js embeds WebAssembly that no WASM notice covers; refusing to package." >&2
    exit 1
  fi
done
cp "$ROOT/proofwidgets-wasm-NOTICE.txt" "$LIC/proofwidgets/THIRD-PARTY-WASM-NOTICES.txt"
cp "$ROOT/proofwidgets-penrose-wasm-NOTICE.txt" "$LIC/proofwidgets/THIRD-PARTY-WASM-PENROSE-NOTICES.txt"

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
test -s "$LIC/proofwidgets/THIRD-PARTY-WASM-NOTICES.txt"
test -s "$LIC/proofwidgets/THIRD-PARTY-WASM-PENROSE-NOTICES.txt"
