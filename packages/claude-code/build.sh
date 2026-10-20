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

# Trust only the system CA store (/etc/ssl/certs), so a fix to ca-certificates
# reaches Claude Code without a rebuild (CVE-2026-111943, eMudhra). Claude
# Code's own default is "bundled,system", a union: a root removed from
# ca-certificates would still be trusted through the Mozilla set compiled into
# the binary. Only when the system bundle exists, since "system" alone with no
# ca-certificates installed would trust nothing. A caller's own value, even an
# empty one, still wins.
if [ -z "\${CLAUDE_CODE_CERT_STORE+set}" ] && [ -s /etc/ssl/certs/ca-certificates.crt ]; then
  export CLAUDE_CODE_CERT_STORE=system
fi

DISABLE_AUTOUPDATER=1 USE_BUILTIN_RIPGREP=0 exec /usr/share/claude/versions/$MINIMAL_ARG_VERSION "\$@"
EOF

chmod -v +x "${OUTPUT_DIR}/usr/bin/claude"
