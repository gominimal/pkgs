#!/bin/sh
set -e

chmod -v +x claude

mkdir -pv $OUTPUT_DIR/usr/{bin,share/claude/versions}
mv -v claude $OUTPUT_DIR/usr/share/claude/versions/$MINIMAL_ARG_VERSION

cat > "${OUTPUT_DIR}/usr/bin/claude" << EOF
#!/bin/bash
# Load the Minimal session plugin if the claude-code-minimal-plugin package is
# also installed. Set MINIMAL_CLAUDE_NO_PLUGIN=1 to opt out.
min_plugin=/usr/share/claude/plugins/minimal
if [ -z "\${MINIMAL_CLAUDE_NO_PLUGIN:-}" ] && [ -d "\$min_plugin" ]; then
  set -- "--plugin-dir=\$min_plugin" "\$@"
fi

DISABLE_AUTOUPDATER=1 USE_BUILTIN_RIPGREP=0 exec /usr/share/claude/versions/$MINIMAL_ARG_VERSION "\$@"
EOF

chmod -v +x "${OUTPUT_DIR}/usr/bin/claude"
