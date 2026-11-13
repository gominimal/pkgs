# lib/httpie.sh: httpie.
#
# httpie 3.2.x trusts a UNION: its SSL context first calls load_default_certs()
# (httpie/compat.py ensure_default_certs_loaded, the system store), then
# requests adds its CA bundle (certifi, or REQUESTS_CA_BUNDLE). Offline feeds
# both to `openssl verify` like lib/python.sh, and accepts if either does.
# (A certifi-only model read FIXED at the pre-fix pin while live connected to
# every bad host. The baseline run is what caught it.)

live_httpie() {
  local o rc; o=$(to http --ignore-stdin --timeout "$TIMEOUT" --print=h GET "https://$1/" 2>&1); rc=$?
  echo "rc=$rc"; echo "$o" | head -1; echo "$o" | grep -Ei 'error|ssl|cert' | head -3
  echo "$o" | grep -q '^HTTP/' && echo "@@CONNECTED@@"; return 0
}

# The interpreter httpie actually runs under (its shebang), not whatever
# python3 is first on PATH.
httpie_python() {
  local h; h=$(command -v http) || return 1
  head -1 "$h" | sed -n 's/^#! *\([^ ]*\).*/\1/p'
}
off_httpie() {
  local py bundle cafile capath
  py=$(httpie_python); [ -n "$py" ] || { echo "cannot find httpie's interpreter"; return 0; }
  bundle=${REQUESTS_CA_BUNDLE:-${CURL_CA_BUNDLE:-}}
  [ -n "$bundle" ] || bundle=$("$py" -I -c 'import requests.certs; print(requests.certs.where())' 2>&1) \
    || { echo "requests.certs failed: $bundle"; return 0; }
  read -r cafile capath <<<"$("$py" -I -c 'import ssl; p = ssl.get_default_verify_paths(); print(p.cafile or "-", p.capath or "-")')"
  echo "httpie python=$py"
  ossl_union "$1" "$cafile" "$capath" "$bundle" -
}

row httpie http "http --version" live_httpie off_httpie "store: openssl verify over system paths + requests' CA bundle (union)"
