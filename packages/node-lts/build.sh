#!/bin/sh
set -e

export CC=gcc

tar -xof "node-v${MINIMAL_ARG_VERSION}.tar.gz"
cd "node-v${MINIMAL_ARG_VERSION}"

# llhttp wasm: rebuilt from undici's C and spliced over the sha-pinned shipped
# base64 blobs. Every pin fails the build on a node bump until re-derived.
LH="python3 ../rebuild-llhttp-wasm.py"
$LH selftest
NPM_UNDICI=6.26.0
NPM_LH=deps/npm/node_modules/undici/lib/llhttp
$LH check-tree --undici 7.29.0 --npm-undici "$NPM_UNDICI"
$LH build deps/undici/src ../wasm --version 7.29.0 --llhttp 9.3.0 --sysroot /usr/lib/wasi
tar -xof "../undici-${NPM_UNDICI}.tar.gz" -C ..
$LH build "../undici-${NPM_UNDICI}" ../wasm-npm --version "$NPM_UNDICI" --llhttp 8.1.0 --sysroot /usr/lib/wasi
$LH splice deps/undici/undici.js 57184a16144b5bc880e29105fa35d75c93dd318563e1b743e110de845e2ab661 ../wasm/llhttp.wasm
$LH splice deps/undici/undici.js 2434215e1f7fa0163f22ce895ddbeb83984fa0aa51e123164e053213e5aca028 ../wasm/llhttp_simd.wasm
$LH splice "$NPM_LH/llhttp-wasm.js" b96063c7ce14045f91f17489d8b30a2bf5129308bd801d7dde715579d16d0e21 ../wasm-npm/llhttp.wasm
$LH splice "$NPM_LH/llhttp_simd-wasm.js" 989f2025b23e92ae5093ceb357093df7bdf2e1e7f1f1bf383b0a4dc69a78151d ../wasm-npm/llhttp_simd.wasm
# Never installed; amaro (swc wasm) is configured out below.
rm deps/undici/src/lib/llhttp/llhttp.wasm deps/undici/src/lib/llhttp/llhttp_simd.wasm \
   deps/undici/src/lib/llhttp/llhttp-wasm.js deps/undici/src/lib/llhttp/llhttp_simd-wasm.js
rm -r deps/amaro
LH_WASM="--wasm ../wasm/llhttp.wasm --wasm ../wasm/llhttp_simd.wasm --wasm ../wasm-npm/llhttp.wasm --wasm ../wasm-npm/llhttp_simd.wasm"
$LH census $LH_WASM --allow-path 'deps/v8/third_party/wasm-api/example/*' --allow-path 'deps/v8/test/*' --allow-path 'deps/v8/src/runtime/runtime-test-wasm.cc' --allow-path 'deps/v8/samples/*' \
    --expect deps/undici/undici.js=2 --expect "$NPM_LH/llhttp-wasm.js=1" --expect "$NPM_LH/llhttp_simd-wasm.js=1" \
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
    --shared-nghttp2 --shared-nghttp3 --shared-ngtcp2 --shared-gtest --shared-cares \
    --without-amaro
    # Note: --shared-lief is omitted; that configure option was not added until Node.js v25.
make -j$(nproc)
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
