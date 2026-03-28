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

# Install mermaid-cli via npm, skipping puppeteer's Chromium download since
# we provide Playwright's Chromium build as an explicit, SHA256-verified input.
export PUPPETEER_SKIP_DOWNLOAD=true
npm install -g --prefix=$OUTPUT_DIR/usr @mermaid-js/mermaid-cli@$MINIMAL_ARG_VERSION

# Extract the Playwright headless shell (both arch variants use the same zip layout).
CHROMIUM_DIR=$OUTPUT_DIR/usr/share/mermaid-cli/chromium
mkdir -p "$CHROMIUM_DIR"
python3 -m zipfile -e chromium-headless-shell-linux*.zip "$CHROMIUM_DIR"
mv "$CHROMIUM_DIR"/chrome-linux/* "$CHROMIUM_DIR"/
rmdir "$CHROMIUM_DIR/chrome-linux"
find "$CHROMIUM_DIR" -type f \( -name "headless_shell" -o -name "*.so" -o -name "*.so.*" \) -exec chmod +x {} +

# Puppeteer config: use headless shell mode, and add --no-sandbox when root.
mkdir -p $OUTPUT_DIR/usr/share/mermaid-cli
cat > $OUTPUT_DIR/usr/share/mermaid-cli/puppeteer.json << 'CONF'
{"headless":"shell","args":["--disable-dev-shm-usage"]}
CONF
cat > $OUTPUT_DIR/usr/share/mermaid-cli/puppeteer-root.json << 'CONF'
{"headless":"shell","args":["--no-sandbox","--disable-dev-shm-usage"]}
CONF

# Replace the npm-created symlink with a wrapper that points puppeteer at our headless shell.
rm -f $OUTPUT_DIR/usr/bin/mmdc
cat > $OUTPUT_DIR/usr/bin/mmdc << 'WRAPPER'
#!/bin/bash
export PUPPETEER_EXECUTABLE_PATH=/usr/share/mermaid-cli/chromium/headless_shell
PUPPETEER_CONF=/usr/share/mermaid-cli/puppeteer.json
if [ "$(id -u)" = "0" ]; then
  PUPPETEER_CONF=/usr/share/mermaid-cli/puppeteer-root.json
fi
exec node /usr/lib/node_modules/@mermaid-js/mermaid-cli/src/cli.js -p "$PUPPETEER_CONF" "$@"
WRAPPER
chmod +x $OUTPUT_DIR/usr/bin/mmdc
