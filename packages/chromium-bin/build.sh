#!/bin/bash
set -euo pipefail

# One complete Chrome for Testing `chrome` zip arrives in the cwd — a
# straight extract. (Before the CfT move amd64 came from the
# chromium-browser-snapshots bucket and arm64 from Playwright's CDN, which
# stopped publishing arm64 builds after r1243.)
mkdir -p _full
if [ "$(uname -m)" = "x86_64" ]; then
  unzip -q chrome-linux64.zip -d _full
else
  unzip -q chrome-linux-arm64.zip -d _full
fi

# The zip is expected to extract to exactly one top-level directory —
# fail loudly if that ever changes.
entries=(_full/*)
if [ "${#entries[@]}" -ne 1 ] || [ ! -d "${entries[0]}" ]; then
  echo "expected exactly one top-level directory in _full, got: ${entries[*]}" >&2
  exit 1
fi
FULL_INNER=$(basename "${entries[0]}")

if [ ! -x "_full/$FULL_INNER/chrome" ]; then
  echo "expected an executable _full/$FULL_INNER/chrome in the CfT bundle" >&2
  exit 1
fi

# Fail closed on runtime files whose absence would surface only at first
# launch (a FATAL on missing icudtl.dat / v8 snapshot, or --dump-dom
# quietly returning nothing).
for required in icudtl.dat v8_context_snapshot.bin resources.pak chrome_100_percent.pak; do
  if [ ! -s "_full/$FULL_INNER/$required" ]; then
    echo "CfT bundle is missing $required — refusing to ship an incomplete browser" >&2
    exit 1
  fi
done

# LICENSING: the CfT `chrome` bundle ships Google's Widevine CDM
# (WidevineCdm/_platform_specific/linux_<arch>/libwidevinecdm.so) under a
# license that forbids distribution without a separate agreement with
# Google ("The Software is not open source software"). Never ship it.
# Chrome runs without it; only EME/DRM media playback is lost.
rm -rf "_full/$FULL_INNER/WidevineCdm"
if find "_full/$FULL_INNER" -iname '*widevine*' | grep -q .; then
  echo "Widevine files survived the strip — refusing to ship them:" >&2
  find "_full/$FULL_INNER" -iname '*widevine*' >&2
  exit 1
fi

REV="${MINIMAL_ARG_REVISION}"
# Shared with chromium-headless-shell-bin so that
# `PLAYWRIGHT_BROWSERS_PATH=/usr/share/playwright-browsers` discovers
# both registry layouts when both pkgs are installed.
SHARE="$OUTPUT_DIR/usr/share/playwright-browsers"
FULL_DEST="$SHARE/chromium-${REV}"

install -d "$FULL_DEST"
cp -R "_full/$FULL_INNER" "$FULL_DEST/$FULL_INNER"

# COMPAT (arm64): the pre-CfT arm64 leg (Playwright's own build) extracted
# to `chrome-linux/chrome`, which playwright-core <= 1.62 looked for on
# arm64. CfT (and playwright-core >= 1.63) use `chrome-linux-arm64/chrome`.
# Keep the old name as a symlink so anything that hardcoded the previous
# path keeps resolving. amd64 is unaffected: `chrome-linux64` was already
# its directory name.
if [ "$FULL_INNER" != "chrome-linux" ] && [ "$FULL_INNER" != "chrome-linux64" ]; then
  ln -s "$FULL_INNER" "$FULL_DEST/chrome-linux"
fi

# Playwright's installer writes this marker after a successful download;
# without it @playwright/test treats the install as incomplete and tries
# to re-download.
touch "$FULL_DEST/INSTALLATION_COMPLETE"

# Stable wrapper so consumers don't need to know per-arch dirs.
install -d "$OUTPUT_DIR/usr/bin"
cat > "$OUTPUT_DIR/usr/bin/chromium" <<EOF
#!/bin/bash
exec /usr/share/playwright-browsers/chromium-${REV}/$FULL_INNER/chrome "\$@"
EOF
chmod +x "$OUTPUT_DIR/usr/bin/chromium"
