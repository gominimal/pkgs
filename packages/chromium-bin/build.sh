#!/bin/bash
set -euo pipefail

# One ungoogled-chromium-portablelinux tarball arrives in the cwd:
# ungoogled-chromium-<version>-<rev>-{x86_64,arm64}_linux.tar.xz.
case "$(uname -m)" in
  x86_64) ARCH_TAG=x86_64; INNER=chrome-linux64 ;;
  aarch64) ARCH_TAG=arm64; INNER=chrome-linux-arm64 ;;
  *) echo "unsupported arch $(uname -m)" >&2; exit 1 ;;
esac
TARBALL="ungoogled-chromium-${MINIMAL_ARG_BROWSER_VERSION}-${MINIMAL_ARG_UNGOOGLED_REVISION}-${ARCH_TAG}_linux.tar.xz"

mkdir -p _full
tar -xof "$TARBALL" -C _full

# The tarball is expected to extract to exactly one top-level directory —
# fail loudly if that ever changes.
entries=(_full/*)
if [ "${#entries[@]}" -ne 1 ] || [ ! -d "${entries[0]}" ]; then
  echo "expected exactly one top-level directory in _full, got: ${entries[*]}" >&2
  exit 1
fi
SRC="${entries[0]}"

if [ ! -x "$SRC/chrome" ] || [ ! -x "$SRC/chromedriver" ]; then
  echo "expected executable chrome and chromedriver in $SRC" >&2
  exit 1
fi

# Fail closed on runtime files whose absence would surface only at first
# launch (a FATAL on missing icudtl.dat / v8 snapshot, or --dump-dom
# quietly returning nothing).
for required in icudtl.dat v8_context_snapshot.bin resources.pak chrome_100_percent.pak; do
  if [ ! -s "$SRC/$required" ]; then
    echo "tarball is missing $required — refusing to ship an incomplete browser" >&2
    exit 1
  fi
done

# The Qt shims are dlopen'd only for a Qt UI and NEED libQt5*/libQt6*,
# which pkgs does not provide. Chromium falls back to its own UI without
# them, so drop them rather than ship unloadable objects. `chrome-wrapper`
# is upstream's desktop launcher script; nothing calls it (our wrapper is
# /usr/bin/chromium), so drop it too.
rm -f "$SRC/libqt5_shim.so" "$SRC/libqt6_shim.so" "$SRC/chrome-wrapper"

# LICENSING: ungoogled-chromium ships no Widevine CDM, and it must stay
# that way (Google's CDM license forbids redistribution). Fail if a
# future tarball ever bundles one.
# (No `find | grep -q`: under pipefail a SIGPIPE on find would make the
# condition false and let the guard pass.)
if [ -n "$(find "$SRC" -iname '*widevine*' -print -quit)" ]; then
  echo "tarball contains Widevine files — refusing to ship them:" >&2
  find "$SRC" -iname '*widevine*' >&2
  exit 1
fi

REV="${MINIMAL_ARG_REVISION}"
# Shared with chromium-headless-shell-bin so that
# `PLAYWRIGHT_BROWSERS_PATH=/usr/share/playwright-browsers` discovers
# both registry layouts when both pkgs are installed. The inner directory
# name is what Playwright's registry expects for this arch.
SHARE="$OUTPUT_DIR/usr/share/playwright-browsers"
FULL_DEST="$SHARE/chromium-${REV}"

install -d "$FULL_DEST"
cp -R "$SRC" "$FULL_DEST/$INNER"

# COMPAT (arm64): the previous arm64 build (Playwright's) extracted to
# `chrome-linux/chrome`; keep that path resolving for anything that
# hardcoded it. amd64 was already `chrome-linux64`.
if [ "$INNER" = "chrome-linux-arm64" ]; then
  ln -s "$INNER" "$FULL_DEST/chrome-linux"
fi

# Playwright's installer writes this marker after a successful download;
# without it @playwright/test treats the install as incomplete and tries
# to re-download.
touch "$FULL_DEST/INSTALLATION_COMPLETE"

# Stable wrapper so consumers don't need to know per-arch dirs.
install -d "$OUTPUT_DIR/usr/bin"
cat > "$OUTPUT_DIR/usr/bin/chromium" <<EOF
#!/bin/bash
exec /usr/share/playwright-browsers/chromium-${REV}/${INNER}/chrome "\$@"
EOF
chmod +x "$OUTPUT_DIR/usr/bin/chromium"
