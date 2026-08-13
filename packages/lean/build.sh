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
cp -a "$STAGE/lib/lean/"*.olean "$OUTPUT_DIR/usr/lib/lean/" 2>/dev/null || true

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
done

# Copy olean files and other lean lib data
for d in "$STAGE/lib/lean/"*/; do
  [ -d "$d" ] && cp -r "$d" "$OUTPUT_DIR/usr/lib/lean/"
done

if [ -d "$STAGE/include" ]; then
  mkdir -p "$OUTPUT_DIR/usr/include"
  cp -r "$STAGE/include/"* "$OUTPUT_DIR/usr/include/"
fi
