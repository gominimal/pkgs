#!/bin/sh
set -e

tar -xof "pnpm-${MINIMAL_ARG_VERSION}.tgz"
cd package

install -d $OUTPUT_DIR/usr/{bin,libexec}
cp -R . $OUTPUT_DIR/usr/libexec/pnpm
# npm tarballs don't carry the +x bit on bin scripts (npm sets it at install
# time); `cp -R` preserves the 0644 the tarball ships. pnpm 11.x's bin/*.cjs
# are 0644, so the `/usr/bin/pnpm` symlink would resolve to a non-executable
# file → "Permission denied" (exit 126) when a package builds with pnpm.
chmod +x $OUTPUT_DIR/usr/libexec/pnpm/bin/*.cjs

# Wrappers rather than symlinks: pnpm refuses global installs when its derived
# global bin dir is not on PATH, and the sandbox PATH is fixed (`pnpm setup`
# has nothing to edit). pnpm 11 honors no npm_config_*/pnpm_config_* env
# spellings for this — PNPM_HOME is the only lever, and its bin/ subdir
# becomes the global bin dir. Defaulting it to ~/.local lands global bins in
# ~/.local/bin (on the session PATH) while a caller's own PNPM_HOME still
# wins. See gominimal/inbox#584.
for cmd in pnpm pnpx; do
  cat > "$OUTPUT_DIR/usr/bin/$cmd" <<WRAPPER
#!/bin/sh
: "\${PNPM_HOME:=\$HOME/.local}"
export PNPM_HOME
exec /usr/libexec/pnpm/bin/$cmd.cjs "\$@"
WRAPPER
  chmod +x "$OUTPUT_DIR/usr/bin/$cmd"
done
