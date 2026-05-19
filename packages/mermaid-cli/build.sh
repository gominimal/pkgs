#!/bin/bash
set -euo pipefail

# Verify GitHub release attestations on the source tarball, if any exist.
# If attestations are present, gh attestation verify must succeed or the build fails.
REPO="mermaid-js/mermaid-cli"
TARBALL="${MINIMAL_ARG_VERSION}.tar.gz"
DIGEST=$(sha256sum "$TARBALL" | cut -d' ' -f1)
if curl -sf "https://api.github.com/repos/${REPO}/attestations/sha256:${DIGEST}" | grep -q '"bundle"'; then
  gh attestation verify "$TARBALL" --repo "$REPO"
fi

# Install mermaid-cli via npm. PUPPETEER_SKIP_DOWNLOAD prevents Puppeteer's
# postinstall from fetching its own chromium — we provide it via the
# chromium-bin pkg as a runtime dep.
export PUPPETEER_SKIP_DOWNLOAD=true
# Hermetic build path: when /npm-cache exists (pre-staged npm cacache),
# install offline. Otherwise fall back to online install for dev. Same
# pattern as bash-language-server / typescript-language-server.
if [ -d /npm-cache ]; then
    NPM_CACHE_RW=/tmp/npm-cache
    cp -r /npm-cache "$NPM_CACHE_RW"
    npm install -g \
        --offline \
        --cache="$NPM_CACHE_RW" \
        --prefix="$OUTPUT_DIR/usr" \
        @mermaid-js/mermaid-cli@$MINIMAL_ARG_VERSION
else
    npm install -g --prefix=$OUTPUT_DIR/usr @mermaid-js/mermaid-cli@$MINIMAL_ARG_VERSION
fi

# Puppeteer config: use headless shell mode, and add --no-sandbox when root.
mkdir -p $OUTPUT_DIR/usr/share/mermaid-cli
cat > $OUTPUT_DIR/usr/share/mermaid-cli/puppeteer.json << 'CONF'
{"headless":"shell","args":["--disable-dev-shm-usage"]}
CONF
cat > $OUTPUT_DIR/usr/share/mermaid-cli/puppeteer-root.json << 'CONF'
{"headless":"shell","args":["--no-sandbox","--disable-dev-shm-usage"]}
CONF

# Replace the npm-created symlink with a wrapper that points puppeteer at
# chromium-bin's headless-shell. /usr/bin/chromium-headless-shell is a
# stable wrapper that resolves to the per-arch headless_shell binary.
rm -f $OUTPUT_DIR/usr/bin/mmdc
cat > $OUTPUT_DIR/usr/bin/mmdc << 'WRAPPER'
#!/bin/bash
export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-headless-shell
PUPPETEER_CONF=/usr/share/mermaid-cli/puppeteer.json
if [ "$(id -u)" = "0" ]; then
  PUPPETEER_CONF=/usr/share/mermaid-cli/puppeteer-root.json
fi
exec node /usr/lib/node_modules/@mermaid-js/mermaid-cli/src/cli.js -p "$PUPPETEER_CONF" "$@"
WRAPPER
chmod +x $OUTPUT_DIR/usr/bin/mmdc
