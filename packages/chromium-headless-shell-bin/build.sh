#!/bin/bash
set -euo pipefail

# One zip arrives in the cwd. Extract into a scratch dir so we can
# discover its (arch-dependent) top-level directory name.
mkdir -p _shell
# The primary zip is arch-specific by NAME, and on amd64 the cwd also
# holds the arm64 donor zip (for the command-resources pak below), so
# extraction must be explicit rather than a glob.
if [ "$(uname -m)" = "x86_64" ]; then
  unzip -q headless-shell.zip -d _shell
else
  unzip -q chromium-headless-shell-linux-arm64.zip -d _shell
fi

# The zip is expected to extract to exactly one top-level directory —
# fail loudly if that ever changes.
entries=(_shell/*)
if [ "${#entries[@]}" -ne 1 ] || [ ! -d "${entries[0]}" ]; then
  echo "expected exactly one top-level directory in _shell, got: ${entries[*]}" >&2
  exit 1
fi
SHELL_INNER=$(basename "${entries[0]}")

# The snapshot zip extracts to headless-shell/headless_shell, but
# Playwright's x64 registry expects
# chrome-headless-shell-linux64/chrome-headless-shell — normalize the
# dir and add a compat symlink so registry discovery keeps working.
# (arm64 extracts to chrome-linux/headless_shell, which already matches
# Playwright's arm64 registry.)
if [ "$(uname -m)" = "x86_64" ] && [ "$SHELL_INNER" = "headless-shell" ]; then
  mv _shell/headless-shell _shell/chrome-headless-shell-linux64
  SHELL_INNER=chrome-headless-shell-linux64
  ln -s headless_shell "_shell/$SHELL_INNER/chrome-headless-shell"

  # The snapshot headless-shell.zip ships only the binary + .paks; the
  # runtime also needs ICU data, the v8 context snapshot, and the
  # GL/SwiftShader fallback libs (all of which the CfT and Playwright
  # bundles carry inline — headless_shell FATALs on missing icudtl.dat).
  # Graft them from the full-browser zip at the same snapshot position,
  # which build_deps fetches on amd64 only.
  mkdir -p _support
  unzip -q chrome-linux.zip \
    "chrome-linux/icudtl.dat" \
    "chrome-linux/v8_context_snapshot.bin" \
    "chrome-linux/libEGL.so" \
    "chrome-linux/libGLESv2.so" \
    "chrome-linux/libvulkan.so.1" \
    "chrome-linux/libvk_swiftshader.so" \
    "chrome-linux/vk_swiftshader_icd.json" \
    -d _support
  cp _support/chrome-linux/* "_shell/$SHELL_INNER/"

  # --dump-dom & friends live in headless_command_resources.pak, which no
  # snapshot artifact ships (the full build rolls it into resources.pak —
  # which is why chromium-bin's launch_check passes without it). Borrow the
  # tiny arch-independent pak from the same-branch Playwright arm64 bundle.
  unzip -q chromium-headless-shell-linux-arm64.zip \
    "chrome-linux/headless_command_resources.pak" -d _cmdres
  cp _cmdres/chrome-linux/headless_command_resources.pak "_shell/$SHELL_INNER/"
fi

# Inner binary differs by source:
#   snapshot amd64 → headless_shell (+ chrome-headless-shell symlink)
#   Playwright arm64 → headless_shell
if [ -x "_shell/$SHELL_INNER/chrome-headless-shell" ]; then
  SHELL_BIN=chrome-headless-shell
elif [ -x "_shell/$SHELL_INNER/headless_shell" ]; then
  SHELL_BIN=headless_shell
else
  echo "unexpected headless-shell layout under _shell/$SHELL_INNER" >&2
  exit 1
fi

REV="${MINIMAL_ARG_REVISION}"
# Shared with chromium-bin so that
# `PLAYWRIGHT_BROWSERS_PATH=/usr/share/playwright-browsers` discovers
# both registry layouts when both pkgs are installed.
SHARE="$OUTPUT_DIR/usr/share/playwright-browsers"
SHELL_DEST="$SHARE/chromium_headless_shell-${REV}"

install -d "$SHELL_DEST"
cp -R "_shell/$SHELL_INNER" "$SHELL_DEST/$SHELL_INNER"

# Playwright's installer writes this marker after a successful download;
# without it @playwright/test treats the install as incomplete and tries
# to re-download.
touch "$SHELL_DEST/INSTALLATION_COMPLETE"

# Stable wrapper so consumers don't need to know per-arch dirs/binaries.
install -d "$OUTPUT_DIR/usr/bin"
cat > "$OUTPUT_DIR/usr/bin/chromium-headless-shell" <<EOF
#!/bin/bash
exec /usr/share/playwright-browsers/chromium_headless_shell-${REV}/$SHELL_INNER/$SHELL_BIN "\$@"
EOF
chmod +x "$OUTPUT_DIR/usr/bin/chromium-headless-shell"
