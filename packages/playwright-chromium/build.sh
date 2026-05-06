#!/bin/bash
set -euo pipefail

# The arm64 zip is named chromium-linux-arm64.zip and unpacks into chrome-linux/;
# the amd64 zip is named chromium-linux.zip and unpacks into chrome-linux64/.
# Detect from what's actually present rather than re-derive from uname.
unzip -q chromium-linux*.zip

if [ -d chrome-linux64 ]; then
  INNER=chrome-linux64
elif [ -d chrome-linux ]; then
  INNER=chrome-linux
else
  echo "Unexpected zip layout: expected chrome-linux64/ or chrome-linux/" >&2
  exit 1
fi

DEST="$OUTPUT_DIR/usr/share/playwright-chromium/chromium-${MINIMAL_ARG_REVISION}"
install -d "$DEST"
cp -R "$INNER" "$DEST/$INNER"

# Playwright's installer writes this marker after a successful download;
# without it @playwright/test treats the install as incomplete and tries
# to re-download.
touch "$DEST/INSTALLATION_COMPLETE"

install -d "$OUTPUT_DIR/usr/bin"
cat > "$OUTPUT_DIR/usr/bin/playwright-chromium" <<EOF
#!/bin/bash
exec /usr/share/playwright-chromium/chromium-${MINIMAL_ARG_REVISION}/$INNER/chrome "\$@"
EOF
chmod +x "$OUTPUT_DIR/usr/bin/playwright-chromium"
