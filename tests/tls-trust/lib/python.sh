# lib/python.sh: python3 (urllib / ssl) and pip.
#
# Offline: Python's ssl module has no API that validates a chain without a
# handshake, and a handshake needs a private key we do not have. So the offline
# rows feed the files Python itself would load (ssl.get_default_verify_paths(),
# pip's vendored certifi) to `openssl verify`, with the flags
# ssl.create_default_context() sets on 3.13+ (-x509_strict -partial_chain).
# Python links the same libssl as the openssl CLI in the box, so this is the
# same verifier over the same store. It does not cover anything Python adds on
# top (there is nothing today); say "store" in the proof column, not "path".

PY_URLLIB='
import sys, urllib.request, urllib.error
try:
    r = urllib.request.urlopen(sys.argv[1], timeout=float(sys.argv[2])); print("@@CONNECTED@@ HTTP", r.status)
except urllib.error.HTTPError as e:
    print("@@CONNECTED@@ HTTP", e.code)
except Exception as e:
    print("FAIL", type(e).__name__, repr(getattr(e, "reason", e)))
'
live_python() { to python3 -I -c "$PY_URLLIB" "https://$1/" "$TIMEOUT" 2>&1 | tail -3; return 0; }

# py_default_paths -> "CAFILE CAPATH" ("-" for a half Python would not load).
py_default_paths() {
  python3 -I -c 'import ssl; p = ssl.get_default_verify_paths(); print(p.cafile or "-", p.capath or "-")'
}
off_python() {
  local cafile capath o
  read -r cafile capath <<<"$(py_default_paths)"
  echo "python default verify paths: cafile=$cafile capath=$capath"
  o=$(ossl_verify_with "$cafile" "$capath" "$1" -x509_strict -partial_chain)
  ossl_verify_verdict "$o"
}

live_pip() {
  local o rc
  o=$(PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_INPUT=1 to python3 -I -m pip download --no-deps --no-cache-dir --retries 0 --timeout "$TIMEOUT" \
        -d "$W/pipdl.$RANDOM" --index-url "https://$1/simple" tls-trust-probe-nonexistent 2>&1); rc=$?
  echo "rc=$rc"; echo "$o" | grep -Ev '^\s*$' | tail -4
  if ! echo "$o" | grep -Eqi -- "$CERT_RE|SSLError"; then
    echo "$o" | grep -Eqi 'Could not find a version|No matching distribution' && echo "@@CONNECTED@@"
  else echo "ssl certificate (pip SSLError)"; fi; return 0
}
# pip (>= 24.2) trusts the UNION of truststore (the system store, same default
# paths as python3) and its vendored certifi bundle, so the chain is accepted
# if either store accepts it.
off_pip() {
  local cafile capath certifi
  read -r cafile capath <<<"$(py_default_paths)"
  certifi=$(python3 -I -c 'from pip._vendor import certifi; print(certifi.where())' 2>&1) || { echo "no pip certifi: $certifi"; return 0; }
  ossl_union "$1" "$cafile" "$capath" "$certifi" -
}

row python-urllib python3 "python3 -V"                                       live_python off_python "store: openssl verify over ssl.get_default_verify_paths()"
row pip           python3 "python3 -I -m pip --version | cut -d' ' -f1-2"    live_pip    off_pip    "store: openssl verify over system paths + pip's certifi (union)"
