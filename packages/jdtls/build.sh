#!/bin/bash
set -euo pipefail

# The distribution is a tarbomb (bin/, plugins/, features/, config_*/);
# unpack it under /usr/share/jdtls.
INSTALL="$OUTPUT_DIR/usr/share/jdtls"
mkdir -p "$INSTALL"
tar xzf "jdt-language-server-${MINIMAL_ARG_VERSION}-${MINIMAL_ARG_BUILD_STAMP}.tar.gz" -C "$INSTALL"

# Wrapper: the upstream bin/jdtls python launcher only knows $HOME/.cache
# for its per-workspace -data dir (it ignores XDG_CACHE_HOME), and hands
# Equinox the shipped config_linux as a *read-only shared* configuration
# area, leaving the writable cascaded one to default to ~/.eclipse. With
# /usr read-only and $HOME not necessarily writable (sessions run as
# `build` with HOME=/), neither default works, so point both at a cache
# dir. The -data key hashes the full canonical workspace path (upstream
# hashes only basename(cwd), which collides for same-named projects and
# trips Eclipse's workspace lock). Caller-supplied -data /
# -configuration still win: argparse and the Equinox launcher both take
# the last occurrence.
mkdir -p "$OUTPUT_DIR/usr/bin"
cat > "$OUTPUT_DIR/usr/bin/jdtls" << 'EOF'
#!/bin/sh
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/jdtls"
DATA="$CACHE/jdtls-$(pwd -P | sha1sum | cut -c1-40)"
exec python3 /usr/share/jdtls/bin/jdtls -configuration "$CACHE/config" -data "$DATA" "$@"
EOF
chmod +x "$OUTPUT_DIR/usr/bin/jdtls"
