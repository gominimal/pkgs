# lib/c-clients.sh: curl, wget, openssl, gnutls-cli, git.
# live_* HOST    -> handshake + HTTP request (see lib/common.sh for the contract)
# off_*  CHAIN   -> path validation against the client's default store, no network

live_curl() {
  local o rc; o=$(to curl -sS -o /dev/null -w '%{http_code}' --max-time "$TIMEOUT" "https://$1/" 2>&1); rc=$?
  echo "rc=$rc $o"; [ $rc -eq 0 ] && echo "@@CONNECTED@@"
  [ $rc -eq 60 ] && echo "SSL certificate problem (curl exit 60)"; return 0
}

live_wget() {
  local o rc; o=$(to wget -O /dev/null --timeout="$TIMEOUT" --tries=1 "https://$1/" 2>&1); rc=$?
  echo "rc=$rc"; echo "$o" | tail -4
  # 8 = server answered with an HTTP error, which still means TLS succeeded.
  { [ $rc -eq 0 ] || [ $rc -eq 8 ]; } && echo "@@CONNECTED@@"
  [ $rc -eq 5 ] && echo "SSL certificate problem (wget exit 5 = SSL verification failure)"; return 0
}

live_openssl() {
  local o rc; o=$(to openssl s_client -connect "$1:443" -servername "$1" -verify_return_error -brief </dev/null 2>&1); rc=$?
  echo "rc=$rc"; echo "$o" | grep -Ei 'verif|error|CONNECTION ESTABLISHED|Protocol' | head -6
  if [ $rc -eq 0 ] && echo "$o" | grep -q 'CONNECTION ESTABLISHED' && ! echo "$o" | grep -qi 'verify error'; then echo "@@CONNECTED@@"; fi
  return 0
}
# OpenSSL's own default store (OPENSSLDIR/cert.pem + certs/, or SSL_CERT_FILE /
# SSL_CERT_DIR when set), exactly what libssl clients load with
# SSL_CTX_set_default_verify_paths. Inside the box OPENSSLDIR is our package's.
off_openssl() {
  local o; o=$(to openssl verify -purpose sslserver -attime "$VERIFY_AT_EPOCH" -untrusted "$1" "$1" 2>&1)
  ossl_verify_verdict "$o"
}

live_gnutls() {
  local o rc; o=$(to gnutls-cli --port 443 "$1" </dev/null 2>&1); rc=$?
  echo "rc=$rc"; echo "$o" | grep -Ei 'verif|trusted|Status|Handshake|error|fail' | head -6
  echo "$o" | grep -q 'Handshake was completed' && echo "@@CONNECTED@@"; return 0
}
# certtool --verify with no --load-ca-certificate uses gnutls's system trust
# (the store gnutls-cli uses), then runs gnutls's real chain verifier.
off_gnutls() {
  local o; o=$(to certtool --verify --verify-purpose=1.3.6.1.5.5.7.3.1 --attime="$VERIFY_AT_ISO" --infile "$1" 2>&1)
  echo "$o" | grep -Ei 'verification output|trusted|issuer|expired|error' | tail -4
  if echo "$o" | grep -q 'Chain verification output: Verified'; then echo '@@ACCEPTED@@'
  elif echo "$o" | grep -Eq 'Chain verification output: Not verified' \
       && echo "$o" | grep -Eq 'issuer is unknown|NOT trusted|distrusted' \
       && ! echo "$o" | grep -Eqi 'expired|not activated|signature failure'; then echo '@@REJECTED@@'
  fi
}

live_git() {
  local o rc; o=$(GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/false GIT_CONFIG_NOSYSTEM=1 to git -c http.lowSpeedTime="$TIMEOUT" -c http.lowSpeedLimit=1 ls-remote "https://$1/x.git" 2>&1); rc=$?
  echo "rc=$rc"; echo "$o" | tail -3
  # TLS errors win; otherwise any HTTP-level answer means the handshake passed.
  if ! echo "$o" | grep -Eqi -- "$CERT_RE"; then
    if [ $rc -eq 0 ] || echo "$o" | grep -Eqi 'returned error: [0-9]|not found|not valid: is this a git repository|could not read Username|Authentication failed|dumb http|unexpected'; then echo "@@CONNECTED@@"; fi
  fi; return 0
}

NA_HANDSHAKE='libcurl/libssl verify only inside a handshake; the store they read is the openssl row'
row curl       curl       "curl --version | head -1 | cut -d' ' -f1-2,5" live_curl    -           "N/A (live-only): $NA_HANDSHAKE"
row wget       wget       "wget --version | head -1 | cut -d' ' -f1-3"   live_wget    -           "N/A (live-only): wget verifies only inside a handshake"
row openssl    openssl    "openssl version | cut -d' ' -f1-2"            live_openssl off_openssl "path: openssl verify, default store"
row gnutls-cli gnutls-cli "gnutls-cli --version | head -1"               live_gnutls  off_gnutls  "path: certtool --verify, gnutls system trust"
row git        git        "git --version"                                live_git     -           "N/A (live-only): $NA_HANDSHAKE"
