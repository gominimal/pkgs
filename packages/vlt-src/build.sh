#!/bin/sh
set -eux
export VLT_TELEMETRY=0 DO_NOT_TRACK=1
SRC=$(pwd)

# 1) esbuild 0.27.7 from source with OUR go.
(cd esbuild-0.27.7 && CGO_ENABLED=0 go build -trimpath -ldflags=-buildid= -o /tmp/esbuild ./cmd/esbuild)
test "$(/tmp/esbuild --version)" = 0.27.7
export ESBUILD_BINARY_PATH=/tmp/esbuild

# 2) Stage 1: run vlt from its TypeScript source. Runtime deps (exact versions
#    from vlt-lock.json) via our node's npm, NO lifecycle scripts.
mkdir -p /tmp/deps
node gen-deps.mjs
printf '@jsr:registry=https://npm.jsr.io\n' > /tmp/deps/.npmrc
(cd /tmp/deps && npm install --omit=dev --ignore-scripts --legacy-peer-deps --no-audit --no-fund)
mkdir -p /tmp/boot && cp -r "$SRC/src" "$SRC/infra" "$SRC/package.json" /tmp/boot/
mv /tmp/deps/node_modules /tmp/boot/node_modules
mkdir -p /tmp/boot/node_modules/@vltpkg
for d in /tmp/boot/src/* /tmp/boot/infra/build; do
  n=$(node -p "require('$d/package.json').name")
  case "$n" in @vltpkg/*) ln -sfn "$d" "/tmp/boot/node_modules/$n" ;; esac
done
BOOT="node --no-warnings --experimental-strip-types /tmp/boot/infra/build/src/bins/vlt.ts"
test "$($BOOT --version)" = 1.3.7

# 3) Stage 2: the bootstrap vlt installs vlt's own monorepo from its own lockfile.
#    vlt's default is to run NO lifecycle scripts (':not(*)'), but its repo
#    vlt.json allows #esbuild/#tailwindcss/#node-pty; override back to none, so
#    no downloaded installer or prebuilt binary executes.
$BOOT install --frozen-lockfile --allow-scripts=':not(*)' >/tmp/install.json 2>&1 || { cat /tmp/install.json; exit 1; }
# Keep prebuilt binaries we did not root out of the tree (and so out of the bundle):
# npm's @esbuild/<platform> executables (we use ours) and resvg's .wasm (optional
# mermaid PNG rendering; bundle.ts tolerates its absence).
mkdir -p /tmp/quarantine
for d in node_modules/.vlt/~npm~@esbuild+* node_modules/.vlt/~npm~@resvg+*; do
  [ -e "$d" ] && mv "$d" /tmp/quarantine/
done
ls /tmp/quarantine | sed 's/^/quarantined: /'

# 4) Bundle with vlt's own release tool, using OUR esbuild.
(cd infra/cli && node --no-warnings --experimental-strip-types ../build/src/prepack.ts)
OUT=infra/cli/.build-publish
test -f "$OUT/package.json"

# 5) Install like packages/vlt does: private prefix + bin symlinks.
P="$OUTPUT_DIR/usr/libexec/vlt"
mkdir -p "$P" "$OUTPUT_DIR/usr/bin"
cp -r "$OUT/." "$P/"
for b in vlt vlr vlx; do ln -s "../libexec/vlt/$b.js" "$OUTPUT_DIR/usr/bin/$b"; done
ls "$P" | head -30

# 6) Compare with the published npm tarball (diagnostic only).
mkdir -p /tmp/npm && tar -xzf vlt-1.3.7.tgz -C /tmp/npm
R="$OUTPUT_DIR/usr/share/vlt-src"; mkdir -p "$R"
(cd /tmp/npm/package && find . -type f | sort | while read f; do echo "$(sha256sum < "$f" | cut -c1-16) $f"; done) > "$R/npm.txt"
(cd "$P" && find . -type f | sort | while read f; do echo "$(sha256sum < "$f" | cut -c1-16) $f"; done) > "$R/ours.txt"
echo "npm files: $(wc -l < "$R/npm.txt")  ours: $(wc -l < "$R/ours.txt")  identical: $(comm -12 "$R/npm.txt" "$R/ours.txt" | wc -l)"
diff "$R/npm.txt" "$R/ours.txt" > "$R/diff.txt" || true
head -40 "$R/diff.txt"
diff /tmp/npm/package/package.json "$P/package.json" | tee "$R/package-json.diff" || true
