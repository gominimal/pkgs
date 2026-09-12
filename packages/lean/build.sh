#!/bin/sh
set -e

tar -xof "v${MINIMAL_ARG_VERSION}.tar.gz"
cd "lean4-${MINIMAL_ARG_VERSION}"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc
export CXXFLAGS="${CFLAGS}"

cmake --preset release

make -C build/release -j$(nproc)

# Install from stage1 output
STAGE=build/release/stage1

mkdir -p "$OUTPUT_DIR/usr/bin"
cp "$STAGE/bin/lean" "$STAGE/bin/lake" "$STAGE/bin/leanc" "$OUTPUT_DIR/usr/bin/"
# leanchecker is optional but useful
if [ -f "$STAGE/bin/leanchecker" ]; then
  cp "$STAGE/bin/leanchecker" "$OUTPUT_DIR/usr/bin/"
fi
if [ -f "$STAGE/bin/leanmake" ]; then
  cp "$STAGE/bin/leanmake" "$OUTPUT_DIR/usr/bin/"
fi

# Libraries are under lib/lean/
mkdir -p "$OUTPUT_DIR/usr/lib/lean"
cp -a "$STAGE/lib/lean/"*.a "$OUTPUT_DIR/usr/lib/lean/" 2>/dev/null || true
cp -a "$STAGE/lib/lean/"*.so* "$OUTPUT_DIR/usr/lib/lean/" 2>/dev/null || true
# The MODULE ROOTS: Init.olean, Std.olean, Lean.olean, Lake.olean sit directly
# in lib/lean/, NOT in a subdirectory, so the per-directory loop below skips
# them entirely. They are what `import Init` resolves, so without them lean
# cannot compile ANY file — not even `#eval 1+1`:
#
#   error: object file '/usr/lib/lean/Init.olean' of module Init does not exist
#
# Hard to spot because everything else looked right: 586 oleans landed under
# Init/ and Std/, and the root-level .a/.so came across in the two copies
# above. The only missing class was the one file per module that makes all the
# rest reachable.
# `*.olean*`, not `*.olean`: since Lean 4.2x each module is THREE files —
# `X.olean`, `X.olean.server`, `X.olean.private` — and lean refuses to load a
# module whose sidecars are missing ("failed to open file
# '/usr/lib/lean/Init.olean.server'"). `.ilean` is the language-server index;
# small, and what makes `lean --server` usable. pkgs#605 shipped the roots'
# `.olean` and lean STILL compiled nothing — this is the other half.
cp -a "$STAGE/lib/lean/"*.olean* "$OUTPUT_DIR/usr/lib/lean/" 2>/dev/null || true
cp -a "$STAGE/lib/lean/"*.ilean "$OUTPUT_DIR/usr/lib/lean/" 2>/dev/null || true
# `.ir` / `.ir.sig`: the compiled IR of each module, a separate file since
# Lean 4.2x. `lean` elaborates and `#eval`s without them, so a compile test
# passes — but `lake` COMPILES the definitions in a lakefile and fails its
# "compiler IR check" on the first private `Init` declaration they touch:
#   failed to compile definition, compiler IR check failed at `config…`:
#   depends on declaration '_private.Init.Data.Array.Basic…'
# so without these no Lake project can even be configured. (Found building
# aeneas-latest; the reference toolchain ships 2,483 of them.)
cp -a "$STAGE/lib/lean/"*.ir "$STAGE/lib/lean/"*.ir.sig "$OUTPUT_DIR/usr/lib/lean/" 2>/dev/null || true

# Then ASSERT they arrived. The copy above swallows errors (the `|| true` is
# there so a layout change upstream doesn't hard-fail the copy), and a glob
# happily matches the remaining files if one is absent — which is precisely how
# this package shipped a lean that could not compile anything, for however long
# it has been broken, with a green build the whole time. Turn a silent
# incomplete publish into a loud build failure. (CR on #605.)
for m in Init Std Lean Lake; do
  if [ ! -f "$OUTPUT_DIR/usr/lib/lean/$m.olean" ]; then
    echo "lean: module root $m.olean is MISSING from the install tree." >&2
    echo "  Without it, 'import $m' cannot resolve and lean compiles nothing." >&2
    echo "  Check whether upstream moved lib/lean/*.olean in this release." >&2
    exit 1
  fi
  # The sidecars are load-bearing too; a root whose .olean.server is absent
  # fails `import` exactly like a missing .olean (Lean >= 4.2x layout).
  if [ ! -f "$OUTPUT_DIR/usr/lib/lean/$m.ir" ]; then
    echo "lean: $m.ir is MISSING — lake needs each module's compiled IR to configure any project." >&2
    exit 1
  fi
  if [ ! -f "$OUTPUT_DIR/usr/lib/lean/$m.olean.server" ]; then
    echo "lean: $m.olean.server is MISSING — Lean splits modules into .olean/.olean.server/.olean.private; lean cannot load $m without all three." >&2
    exit 1
  fi
done

# Copy olean files and other lean lib data
for d in "$STAGE/lib/lean/"*/; do
  [ -d "$d" ] && cp -r "$d" "$OUTPUT_DIR/usr/lib/lean/"
done

if [ -d "$STAGE/include" ]; then
  mkdir -p "$OUTPUT_DIR/usr/include"
  cp -r "$STAGE/include/"* "$OUTPUT_DIR/usr/include/"
fi
