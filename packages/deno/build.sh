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
#
# The wrapper also defaults DENO_TLS_CA_STORE to `system`. deno's own default
# is `mozilla`: the webpki-roots list compiled into the binary, so removing a
# CA meant waiting for a deno release and rebuilding (CVE-2026-111943,
# eMudhra). With `system`, deno reads /etc/ssl/certs at startup and nothing
# else, so a fix to ca-certificates reaches it without a rebuild. `system`
# alone, not `mozilla,system`: the list is a union, and a root removed from
# ca-certificates would still be trusted through the compiled-in copy.
# The default applies only when the system bundle exists. With no
# ca-certificates in the environment, `system` would give deno an empty
# store and every TLS connection would fail, so it keeps `mozilla`. A
# caller's own DENO_TLS_CA_STORE (including an empty one) still wins.
mkdir -p $OUTPUT_DIR/usr/bin $OUTPUT_DIR/usr/libexec/deno
install -m 755 deno $OUTPUT_DIR/usr/libexec/deno/deno
cat > "$OUTPUT_DIR/usr/bin/deno" <<'WRAPPER'
#!/bin/sh
if [ -n "${HOME:-}" ]; then
  : "${DENO_INSTALL_ROOT:=$HOME/.local}"
  export DENO_INSTALL_ROOT
fi
if [ -z "${DENO_TLS_CA_STORE+set}" ] && [ -s /etc/ssl/certs/ca-certificates.crt ]; then
  DENO_TLS_CA_STORE=system
  export DENO_TLS_CA_STORE
fi
exec /usr/libexec/deno/deno "$@"
WRAPPER
chmod +x "$OUTPUT_DIR/usr/bin/deno"
