# lib/rust.sh: uv (rustls + webpki-roots compiled in) and uv with
# UV_SYSTEM_CERTS=1 (rustls-native-certs). rustls-webpki only verifies inside
# a handshake and uv exposes no verify command, so both rows are live-only.
# The compiled-in root list is what `pkgmgr truststores` inventories.

live_uv_common() {
  local o rc
  o=$(echo tls-trust-probe-nonexistent | UV_NO_CACHE=1 UV_HTTP_RETRIES=0 UV_HTTP_TIMEOUT="$TIMEOUT" UV_PYTHON_DOWNLOADS=never UV_NO_CONFIG=1 \
        to uv pip compile --no-header --index-url "https://$1/simple" - 2>&1); rc=$?
  echo "rc=$rc"; echo "$o" | grep -Ev '^\s*$' | tail -5
  if ! echo "$o" | grep -Eqi -- "$CERT_RE"; then
    echo "$o" | grep -Eqi 'not found in the package registry|was not found|404|status client error|No solution found|Unsupported .Content-Type|Expected JSON or HTML' && echo "@@CONNECTED@@"
  fi; return 0
}
live_uv()        { live_uv_common "$1"; }
live_uv_native() { UV_SYSTEM_CERTS=1 live_uv_common "$1"; }
# blocklist variant: the system store uv reads is the anchors-included one, so
# only rustls-webpki's distrusted-SPKI list can refuse.
live_uv_bl()     { UV_SYSTEM_CERTS=1 SSL_CERT_FILE=$W/negctl.pem SSL_CERT_DIR=$W/emptydir live_uv_common "$1"; }

row uv              uv "uv --version | cut -d' ' -f1-2" live_uv        - "N/A (live-only): rustls verifies only in a handshake; roots are compiled in"
row uv-system-certs uv "echo UV_SYSTEM_CERTS=1"         live_uv_native - "N/A (live-only): rustls verifies only in a handshake"
row uv-blocklist    uv "echo uv, anchors trusted"       live_uv_bl     - "N/A (live-only): rustls-webpki's SPKI list fires only in a handshake"
