#!/bin/sh
set -e

export CC=gcc

tar -xof "node-v${MINIMAL_ARG_VERSION}.tar.gz"
cd "node-v${MINIMAL_ARG_VERSION}"

# CVE-2026-111943 is fixed upstream (nodejs/node#66871 SPKI blocklist,
# #66877 NSS 3.131.1 roots). Fail the build if a future version regresses either.
grep -q "constexpr SpkiHash kBlockedSPKIs" src/crypto/crypto_context.cc &&
grep -q "InstallCertVerifyCallback(sc->ctx_.get());" src/crypto/crypto_context.cc || {
  echo "ERROR: upstream CVE-2026-111943 SPKI blocklist missing from src/crypto/crypto_context.cc" >&2
  exit 1
}
if grep -q "emSign ECC Root CA - G3" src/node_root_certs.h; then
  echo "ERROR: emSign ECC Root CA - G3 is back in src/node_root_certs.h (CVE-2026-111943)" >&2
  exit 1
fi

# llhttp wasm: rebuilt from undici's C and spliced over the sha-pinned shipped
# base64 blobs. Every pin fails the build on a node bump until re-derived.
LH="python3 /usr/share/llhttp-wasm-rebuild/rebuild-llhttp-wasm.py"
UNDICI="${MINIMAL_ARG_UNDICI:?build.ncl forwards undici}"
UNDICI_LLHTTP="${MINIMAL_ARG_UNDICI_LLHTTP:?build.ncl forwards undici_llhttp}"
NPM_UNDICI="${MINIMAL_ARG_NPM_UNDICI:?build.ncl forwards npm_undici}"
AMARO_VERSION="${MINIMAL_ARG_AMARO:?build.ncl forwards amaro}"
NPM_LH=deps/npm/node_modules/undici/lib/llhttp
$LH check-tree --undici "$UNDICI" --npm-undici "$NPM_UNDICI"
$LH build deps/undici/src ../wasm --version "$UNDICI" --llhttp "$UNDICI_LLHTTP" --sysroot /usr/lib/wasi
tar -xof "../undici-${NPM_UNDICI}.tar.gz" -C ..
$LH build "../undici-${NPM_UNDICI}" ../wasm-npm --version "$NPM_UNDICI" --llhttp "${MINIMAL_ARG_NPM_UNDICI_LLHTTP:?build.ncl forwards npm_undici_llhttp}" --sysroot /usr/lib/wasi
$LH splice deps/undici/undici.js ab4573a06c43574936dc98c3943b10a4ee32798e9797329e9f327e5f64115f54 ../wasm/llhttp.wasm
$LH splice deps/undici/undici.js 18403ee56fab07f89a845028bad358bb3ebcda213f8e2ec0989a991e9c33da69 ../wasm/llhttp_simd.wasm
$LH splice "$NPM_LH/llhttp-wasm.js" b96063c7ce14045f91f17489d8b30a2bf5129308bd801d7dde715579d16d0e21 ../wasm-npm/llhttp.wasm
$LH splice "$NPM_LH/llhttp_simd-wasm.js" 989f2025b23e92ae5093ceb357093df7bdf2e1e7f1f1bf383b0a4dc69a78151d ../wasm-npm/llhttp_simd.wasm
# Never installed.
rm deps/undici/src/lib/llhttp/llhttp.wasm deps/undici/src/lib/llhttp/llhttp_simd.wasm \
   deps/undici/src/lib/llhttp/llhttp-wasm.js deps/undici/src/lib/llhttp/llhttp_simd-wasm.js
# undici 8.12 vendors milo (Rust) as two base64 wasm carriers in its source tree; node's
# bundled undici.js compiles milo out (`getMiloEnabled } = false ? null : {}`), so never installed.
rm deps/undici/src/lib/milo/simd.js deps/undici/src/lib/milo/no-simd.js
# amaro (`node x.ts` type stripping): swc's wasm, rebuilt by packages/amaro-wasm and spliced
# over the sha-pinned shipped blob; --wasm-bindgen also renames the glue's one renumbered shim.
AMARO=/usr/share/amaro-wasm/$AMARO_VERSION/wasm_bg.wasm
grep -q "\"version\": \"$AMARO_VERSION\"" deps/amaro/package.json || { echo "deps/amaro is not $AMARO_VERSION" >&2; exit 1; }
$LH splice deps/amaro/dist/index.js 79c79a0be6c92c7d8a1968cb1a7bed88737755d38d2b47ddfe4da5e51796a4e9 "$AMARO" --wasm-bindgen
LH_WASM="--wasm ../wasm/llhttp.wasm --wasm ../wasm/llhttp_simd.wasm --wasm ../wasm-npm/llhttp.wasm --wasm ../wasm-npm/llhttp_simd.wasm --wasm $AMARO"
$LH census $LH_WASM --allow-path 'deps/v8/third_party/wasm-api/example/*' --allow-path 'deps/v8/test/*' --allow-path 'deps/v8/src/runtime/runtime-test-wasm.cc' --allow-path 'deps/v8/samples/*' \
    --expect deps/undici/undici.js=2 --expect "$NPM_LH/llhttp-wasm.js=1" --expect "$NPM_LH/llhttp_simd-wasm.js=1" --expect deps/amaro/dist/index.js=1 \
    deps lib src

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr \
    --with-intl=system-icu --shared-openssl --shared-zlib --shared-zstd --shared-sqlite --shared-libuv \
    --shared-nghttp2 --shared-nghttp3 --shared-ngtcp2 --shared-gtest  --shared-lief --shared-cares
make -j$(nproc)
# type stripping runs on the rebuilt amaro
printf 'const n: number = 6;\nconsole.log(n * 7);\n' > ../strip.ts
out/Release/node ../strip.ts | grep -qx 42
$LH smoke out/Release/node ../wasm/llhttp.wasm ../wasm/llhttp_simd.wasm \
    ../wasm-npm/llhttp.wasm ../wasm-npm/llhttp_simd.wasm --require deps/npm/node_modules/undici --fetch
make DESTDIR=$OUTPUT_DIR install

# npm's compiled-in global prefix is /usr, which is the read-only package
# store at session time, so every `npm i -g` fails with ENOENT. Ship a
# builtin npmrc (npm's lowest-precedence config source, overridable by any
# user config) pointing globals at ~/.local, whose bin/ is already on the
# session PATH. See gominimal/inbox#559.
printf 'prefix=~/.local\n' > "$OUTPUT_DIR/usr/lib/node_modules/npm/npmrc"

# Installed wasm is exactly the rebuilt blobs: js2c'd into node, verbatim in npm's undici.
# V8 test runtime (runtime-test-wasm.cc) compiles in two type-section-only modules.
$LH census -C "$OUTPUT_DIR" $LH_WASM --expect usr/bin/node=2+ --allow-raw usr/bin/node=2 \
    --expect usr/lib/node_modules/npm/node_modules/undici/lib/llhttp/llhttp-wasm.js=1 \
    --expect usr/lib/node_modules/npm/node_modules/undici/lib/llhttp/llhttp_simd-wasm.js=1 \
    usr
