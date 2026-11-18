#!/bin/sh
set -e

export CC=gcc
TOP=$(pwd)
NODE1=/usr/bin/node # node-26.12.1
ESBUILD_VERSION="${MINIMAL_ARG_ESBUILD:?build.ncl forwards esbuild}"
NODE1_VERSION="${MINIMAL_ARG_NODE1:?build.ncl forwards node1}"
test "$("$NODE1" --version)" = "v${NODE1_VERSION}" || { echo "/usr/bin/node is not v${NODE1_VERSION} (node-26.12.1)" >&2; exit 1; }
test "$(esbuild --version)" = "$ESBUILD_VERSION" || { echo "esbuild is not $ESBUILD_VERSION" >&2; exit 1; }
REGEN="$TOP/regen"
mkdir -p "$REGEN"
BI="$REGEN/BUILDINFO"

# report <label> <reference> <regenerated>: whether the two are identical, printed and recorded in
# BUILDINFO; a difference is a measurement, not a failure
report() {
  a=$(sha256sum < "$2" | cut -d' ' -f1)
  b=$(sha256sum < "$3" | cut -d' ' -f1)
  if [ "$a" = "$b" ]; then r=identical; else r=differs; fi
  echo "@@REGEN $r $1: reference=$a regenerated=$b"
  printf '%s: %s (reference %s, regenerated %s)\n' "$1" "$r" "$a" "$b" >> "$BI"
  if [ "$r" = differs ]; then diff -u "$2" "$3" | cut -c1-200 | head -n 80 || true; fi
}

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
# npm is installed whole and stays upstream's; only its undici's wasm is rebuilt.
$LH splice "$NPM_LH/llhttp-wasm.js" b96063c7ce14045f91f17489d8b30a2bf5129308bd801d7dde715579d16d0e21 ../wasm-npm/llhttp.wasm
$LH splice "$NPM_LH/llhttp_simd-wasm.js" 989f2025b23e92ae5093ceb357093df7bdf2e1e7f1f1bf383b0a4dc69a78151d ../wasm-npm/llhttp_simd.wasm
# amaro (`node x.ts` type stripping): swc's wasm, rebuilt by packages/amaro-wasm; the bundle
# that carries it is regenerated below.
AMARO=/usr/share/amaro-wasm/$AMARO_VERSION/wasm_bg.wasm
grep -q "\"version\": \"$AMARO_VERSION\"" deps/amaro/package.json || { echo "deps/amaro is not $AMARO_VERSION" >&2; exit 1; }

printf 'node v%s\n' "$MINIMAL_ARG_VERSION" > "$BI"
printf 'regenerated: deps/undici/undici.js deps/amaro/dist/index.js deps/minimatch/index.js\n' >> "$BI"
printf 'by: esbuild %s, node-26.12.1 %s\n' "$ESBUILD_VERSION" "$("$NODE1" --version)" >> "$BI"
printf 'as shipped: deps/acorn deps/minimatch/dist deps/npm (wasm rebuilt) src/node_root_certs.h deps/llhttp deps/undici/src/deps/llhttp\n' >> "$BI"

# --- deps/undici/undici.js: undici's build:node script, in its source tree as update-undici.sh
# runs it (esbuild, then scripts/strip-comments.js, a utf8-to-latin1 transcode, on a node)
U=deps/undici/src
grep -qF '"build:node": "esbuild index-fetch.js --bundle --platform=node --outfile=undici-fetch.js --define:esbuildDetection=1 --keep-names && node scripts/strip-comments.js"' "$U/package.json" ||
  { echo "undici's build:node script changed" >&2; exit 1; }
undici_bundle() {
  (cd "$U" &&
    esbuild index-fetch.js --bundle --platform=node --outfile=undici-fetch.js --define:esbuildDetection=1 --keep-names &&
    "$NODE1" scripts/strip-comments.js)
  mv "$U/undici-fetch.js" "$1"
}
# from the shipped inputs: the measure of esbuild and its flags against upstream's file
undici_bundle "$REGEN/undici-shipped-wasm.js"
report "deps/undici/undici.js from the shipped inputs vs shipped" deps/undici/undici.js "$REGEN/undici-shipped-wasm.js"
# undici's own wasm carriers take the rebuilt blobs, then the bundle is the one node embeds
$LH splice "$U/lib/llhttp/llhttp-wasm.js" ab4573a06c43574936dc98c3943b10a4ee32798e9797329e9f327e5f64115f54 ../wasm/llhttp.wasm
$LH splice "$U/lib/llhttp/llhttp_simd-wasm.js" 18403ee56fab07f89a845028bad358bb3ebcda213f8e2ec0989a991e9c33da69 ../wasm/llhttp_simd.wasm
undici_bundle "$REGEN/undici.js"
cp deps/undici/undici.js "$REGEN/undici-spliced.js"
$LH splice "$REGEN/undici-spliced.js" ab4573a06c43574936dc98c3943b10a4ee32798e9797329e9f327e5f64115f54 ../wasm/llhttp.wasm
$LH splice "$REGEN/undici-spliced.js" 18403ee56fab07f89a845028bad358bb3ebcda213f8e2ec0989a991e9c33da69 ../wasm/llhttp_simd.wasm
report "deps/undici/undici.js vs the shipped one with the rebuilt wasm spliced in" "$REGEN/undici-spliced.js" "$REGEN/undici.js"

# --- deps/amaro/dist/index.js: amaro's build script runs esbuild.config.mjs, whose first build is
# this file (the esbuild-plugin-copy there only copies files; `tsc --noCheck` emits declarations).
AM="$TOP/amaro-$AMARO_VERSION"
SWC_SCRIPTS="amaro-$AMARO_VERSION/deps/swc/bindings/binding_typescript_wasm/scripts"
tar -xof "$TOP/v$AMARO_VERSION.tar.gz" -C "$TOP" "amaro-$AMARO_VERSION/package.json" "amaro-$AMARO_VERSION/tsconfig.json" \
    "amaro-$AMARO_VERSION/esbuild.config.mjs" "amaro-$AMARO_VERSION/src" "amaro-$AMARO_VERSION/lib" "$SWC_SCRIPTS/patch.mjs"
grep -q "\"version\": \"$AMARO_VERSION\"" "$AM/package.json" || { echo "amaro's tag is not $AMARO_VERSION" >&2; exit 1; }
grep -qF 'entryPoints: ["src/index.ts"],' "$AM/esbuild.config.mjs" && grep -qF 'target: "node22",' "$AM/esbuild.config.mjs" ||
  { echo "amaro's esbuild.config.mjs changed" >&2; exit 1; }
amaro_bundle() {
  (cd "$AM" && esbuild src/index.ts --bundle --platform=node --target=node22 --outfile=dist/index.js)
  mv "$AM/dist/index.js" "$1"
}
amaro_bundle "$REGEN/amaro-shipped-wasm.js"
report "deps/amaro/dist/index.js from the tag's lib/wasm.js vs shipped" deps/amaro/dist/index.js "$REGEN/amaro-shipped-wasm.js"
# lib/wasm.js: packages/amaro-wasm's wasm-bindgen output, inlined by swc's scripts/patch.mjs on
# node-26.12.1, the last step of amaro's tools/build-wasm.js
W="$TOP/amaro-pkg"
mkdir -p "$W/pkg"
cp "/usr/share/amaro-wasm/$AMARO_VERSION/wasm.js" "$AMARO" "$W/pkg/"
chmod u+w "$W/pkg/wasm.js" "$W/pkg/wasm_bg.wasm"
printf '{"files":["wasm_bg.wasm","wasm.js"]}\n' > "$W/pkg/package.json" # patch.mjs rewrites it; unused
(cd "$W" && "$NODE1" "$TOP/$SWC_SCRIPTS/patch.mjs")
grep -q "Buffer.from('AGFzbQ" "$W/pkg/wasm.js" && ! grep -q "readFileSync(path)" "$W/pkg/wasm.js" ||
  { echo "patch.mjs did not inline the wasm into wasm.js" >&2; exit 1; }
report "amaro lib/wasm.js, rebuilt vs the tag's" "$AM/lib/wasm.js" "$W/pkg/wasm.js"
cp "$W/pkg/wasm.js" "$AM/lib/wasm.js"
amaro_bundle "$REGEN/amaro.js"
cp deps/amaro/dist/index.js "$REGEN/amaro-spliced.js"
$LH splice "$REGEN/amaro-spliced.js" 79c79a0be6c92c7d8a1968cb1a7bed88737755d38d2b47ddfe4da5e51796a4e9 "$AMARO" --wasm-bindgen
report "deps/amaro/dist/index.js vs the shipped one with the rebuilt wasm spliced in" "$REGEN/amaro-spliced.js" "$REGEN/amaro.js"

# --- deps/minimatch/index.js: its node-build script, outside the node tree as update-minimatch.sh
# runs it (node's tsconfig.json would apply otherwise), over the brace-expansion and
# balanced-match its lockfile pins; npm bundles the same versions, so they come from deps/npm
M=deps/minimatch
grep -qF '"node-build": "esbuild ./dist/commonjs/index.js --bundle --platform=node --outfile=index.js"' "$M/package.json" ||
  { echo "minimatch's node-build script changed" >&2; exit 1; }
MW="$TOP/minimatch"
mkdir -p "$MW/node_modules"
cp -R "$M/package.json" "$M/dist" "$MW/"
for p in brace-expansion balanced-match; do cp -R "deps/npm/node_modules/$p" "$MW/node_modules/"; done
python3 - "$M/package-lock.json" "$MW/node_modules" <<'EOF'
import json, sys
lock = json.load(open(sys.argv[1]))["packages"]
for p in ("brace-expansion", "balanced-match"):
    want = lock["node_modules/" + p]["version"]
    got = json.load(open(f"{sys.argv[2]}/{p}/package.json"))["version"]
    if want != got:
        sys.exit(f"minimatch's lockfile pins {p} {want}, deps/npm has {got}")
EOF
(cd "$MW" && esbuild ./dist/commonjs/index.js --bundle --platform=node --outfile=index.js)
report "deps/minimatch/index.js vs shipped" "$M/index.js" "$MW/index.js"

# the shipped copies go; the regenerated ones take their place
rm deps/undici/undici.js deps/amaro/dist/index.js "$M/index.js"
cp "$REGEN/undici.js" deps/undici/undici.js
cp "$REGEN/amaro.js" deps/amaro/dist/index.js
cp "$MW/index.js" "$M/index.js"
for f in deps/undici/undici.js deps/amaro/dist/index.js "$M/index.js"; do
  printf 'sha256 %s %s\n' "$(sha256sum < "$f" | cut -d' ' -f1)" "$f" >> "$BI"
done

# Never installed.
rm deps/undici/src/lib/llhttp/llhttp.wasm deps/undici/src/lib/llhttp/llhttp_simd.wasm \
   deps/undici/src/lib/llhttp/llhttp-wasm.js deps/undici/src/lib/llhttp/llhttp_simd-wasm.js
# undici 8.12 vendors milo (Rust) as two base64 wasm carriers in its source tree; node's
# bundled undici.js compiles milo out (`getMiloEnabled } = false ? null : {}`), so never installed.
rm deps/undici/src/lib/milo/simd.js deps/undici/src/lib/milo/no-simd.js
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

# Trust the system CA store (/etc/ssl, from ca-certificates) instead of the
# Mozilla roots compiled into node, so a CA removed from ca-certificates
# (CVE-2026-111943, eMudhra) stops being trusted without a node rebuild.
# --openssl-use-def-ca-store defines NODE_OPENSSL_CERT_STORE, which makes
# `--use-openssl-ca` the default (configure.py, src/node_options.h at
# v26.12.1). With it, NewRootCertStore() in src/crypto/crypto_context.cc calls
# X509_STORE_set_default_paths() INSTEAD of adding the bundled roots: the store
# is replaced, not extended. Our openssl is built with --openssldir=/etc/ssl,
# so the default paths are /etc/ssl/cert.pem and /etc/ssl/certs ($SSL_CERT_FILE
# and $SSL_CERT_DIR override them, as in OpenSSL). NODE_EXTRA_CA_CERTS is still
# added on top. `--use-system-ca` is accepted but has no effect in this mode.
# tls.getCACertificates('default') still lists the bundled roots: lib/tls.js
# keys that list on the --use-openssl-ca flag, not on the store in use.
# Opt out with `--use-bundled-ca`, on the command line or in NODE_OPTIONS
# (kAllowedInEnvvar), which restores the compiled-in store.
./configure --prefix=/usr --openssl-use-def-ca-store \
    --with-intl=system-icu --shared-openssl --shared-zlib --shared-zstd --shared-sqlite --shared-libuv \
    --shared-nghttp2 --shared-nghttp3 --shared-ngtcp2 --shared-gtest  --shared-lief --shared-cares
make -j$(nproc)
# type stripping runs on the regenerated amaro
printf 'const n: number = 6;\nconsole.log(n * 7);\n' > ../strip.ts
out/Release/node ../strip.ts | grep -qx 42
$LH smoke out/Release/node ../wasm/llhttp.wasm ../wasm/llhttp_simd.wasm \
    ../wasm-npm/llhttp.wasm ../wasm-npm/llhttp_simd.wasm --require deps/npm/node_modules/undici --fetch
make DESTDIR=$OUTPUT_DIR install

# The flag must have reached the binary: its --help marks the OpenSSL store as
# the default only when NODE_OPENSSL_CERT_STORE is defined (src/node_options.cc;
# tr undoes the help text's line folding).
"$OUTPUT_DIR/usr/bin/node" --help | tr -s ' \n' ' ' | grep -q "use OpenSSL's default CA store (default)" || {
  echo "ERROR: node was not built with --openssl-use-def-ca-store" >&2
  exit 1
}

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

install -Dm 0644 "$BI" "$OUTPUT_DIR/usr/share/node/BUILDINFO"
cat "$BI"
