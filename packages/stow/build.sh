#!/bin/sh
# Imported from Wolfi `stow` (2.4.1, autotools) by pkgmgr import-wolfi.
set -eu
# Reproducibility flags (see AGENTS.md).
export CFLAGS="${CFLAGS:-} -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="${LDFLAGS:-} -Wl,--build-id=none"
export ARFLAGS=Drc

# The GNU tarball ships pre-built texinfo docs (doc/stow.info,
# doc/manual-single.html), but minimal has no texinfo/makeinfo to regenerate
# them — make's doc rules would `rm` the shipped file then fail on the missing
# tool. Shim `makeinfo` to restore the shipped doc into each rule's -o target.
mkdir -p .shim/docs
cp -a doc/*.info doc/*.html .shim/docs/ 2>/dev/null || true
cat > .shim/makeinfo <<'SHIM'
#!/bin/sh
out=""; prev=""
for a in "$@"; do [ "$prev" = "-o" ] && out=$a; prev=$a; done
[ -n "$out" ] || exit 0
mkdir -p "$(dirname "$out")"
shipped="$SHIM_DOCS/$(basename "$out")"
if [ -f "$shipped" ]; then cp "$shipped" "$out"; else : > "$out"; fi
SHIM
chmod +x .shim/makeinfo
export SHIM_DOCS="$PWD/.shim/docs"
export PATH="$PWD/.shim:$PATH"

if [ ! -x ./configure ]; then autoreconf -fi; fi
./configure --prefix=/usr --enable-deterministic-archives
make -j"$(nproc)"
make DESTDIR="$OUTPUT_DIR" install
# Drop libtool archives — they embed absolute build-time paths.
find "$OUTPUT_DIR" -name '*.la' -delete
