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

# CVE-2026-111943: trust only the OS store (/etc/ssl/certs, from
# ca-certificates) by default. Claude Code's default is "bundled,system", and
# the bundled set (its Bun runtime's compiled-in Mozilla roots) still carries
# emSign ECC Root CA - G3, the anchor for the compromised eMudhra
# intermediates. A caller's own CLAUDE_CODE_CERT_STORE still wins, and
# NODE_EXTRA_CA_CERTS is still appended.
: "\${CLAUDE_CODE_CERT_STORE:=system}"
export CLAUDE_CODE_CERT_STORE

DISABLE_AUTOUPDATER=1 USE_BUILTIN_RIPGREP=0 exec /usr/share/claude/versions/$MINIMAL_ARG_VERSION "\$@"
EOF

chmod -v +x "${OUTPUT_DIR}/usr/bin/claude"
