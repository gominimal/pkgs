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
# It also defaults DENO_TLS_CA_STORE=system (CVE-2026-111943). deno's default
# store is "mozilla": webpki-roots compiled into the binary (0.26.1 in 2.9.7),
# which still trusts emSign ECC Root CA - G3, the anchor for the compromised
# eMudhra intermediates, and its rustls-webpki (0.103.13) has no SPKI
# blocklist. "system" reads ONLY the OS store (/etc/ssl/certs, from
# ca-certificates), which drops those roots, and leaves the bundled set out.
# A caller's own DENO_TLS_CA_STORE still wins. Revisit on the first deno
# release with denoland/deno#37046 (rustls-webpki 0.103.16, webpki-roots 1.0.10).
mkdir -p $OUTPUT_DIR/usr/bin $OUTPUT_DIR/usr/libexec/deno
install -m 755 deno $OUTPUT_DIR/usr/libexec/deno/deno
cat > "$OUTPUT_DIR/usr/bin/deno" <<'WRAPPER'
#!/bin/sh
if [ -n "${HOME:-}" ]; then
  : "${DENO_INSTALL_ROOT:=$HOME/.local}"
  export DENO_INSTALL_ROOT
fi
: "${DENO_TLS_CA_STORE:=system}"
export DENO_TLS_CA_STORE
exec /usr/libexec/deno/deno "$@"
WRAPPER
chmod +x "$OUTPUT_DIR/usr/bin/deno"
