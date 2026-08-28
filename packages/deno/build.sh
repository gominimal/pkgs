#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  DENOARCH=x86_64 ;;
  aarch64) DENOARCH=aarch64 ;;
  *)       echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

python3 -m zipfile -e "deno-${DENOARCH}-unknown-linux-gnu.zip" .

# Install. The real binary lives in libexec; /usr/bin/deno is a wrapper that
# defaults DENO_INSTALL_ROOT so `deno install -g` bins land in ~/.local/bin
# (on the session PATH) rather than the off-PATH ~/.deno/bin default; a
# caller's own DENO_INSTALL_ROOT still wins. See gominimal/inbox#584.
mkdir -p $OUTPUT_DIR/usr/bin $OUTPUT_DIR/usr/libexec/deno
install -m 755 deno $OUTPUT_DIR/usr/libexec/deno/deno
cat > "$OUTPUT_DIR/usr/bin/deno" <<'WRAPPER'
#!/bin/sh
: "${DENO_INSTALL_ROOT:=$HOME/.local}"
export DENO_INSTALL_ROOT
exec /usr/libexec/deno/deno "$@"
WRAPPER
chmod +x "$OUTPUT_DIR/usr/bin/deno"
