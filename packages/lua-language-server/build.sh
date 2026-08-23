#!/bin/sh
set -ex

# The release is a tarbomb (bin/, script/, meta/, locale/, main.lua, ...);
# unpack it under /usr/share/lua-language-server.
INSTALL="$OUTPUT_DIR/usr/share/lua-language-server"
mkdir -p "$INSTALL"
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  SUFFIX="linux-x64" ;;
  aarch64) SUFFIX="linux-arm64" ;;
  *) echo "unsupported arch: $ARCH" >&2; exit 1 ;;
esac
tar xzf "lua-language-server-${MINIMAL_ARG_VERSION}-${SUFFIX}.tar.gz" -C "$INSTALL"

# Wrapper: the server resolves its resources relative to the real binary,
# but by default also writes logs and generated meta files next to the
# install root, which is read-only here — point those at writable paths.
mkdir -p "$OUTPUT_DIR/usr/bin"
cat > "$OUTPUT_DIR/usr/bin/lua-language-server" << 'EOF'
#!/bin/sh
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/lua-language-server"
mkdir -p "$CACHE/log" "$CACHE/meta"
exec /usr/share/lua-language-server/bin/lua-language-server \
  --logpath="$CACHE/log" --metapath="$CACHE/meta" "$@"
EOF
chmod +x "$OUTPUT_DIR/usr/bin/lua-language-server"
