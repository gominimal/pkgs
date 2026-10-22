# lib/common.sh: shared helpers for the TLS trust harness. Sourced by run.sh.
#
# Probe contracts (every probe prints free-form output to stdout):
#   live    probes print @@CONNECTED@@ only when the server's HTTP layer
#           answered, i.e. the handshake completed and the chain was trusted.
#   offline probes print @@ACCEPTED@@ when the runtime's verifier built a
#           trusted path, or @@REJECTED@@ when it refused the chain for a
#           TRUST reason (unknown issuer, untrusted, distrusted, blocked).
#           Anything else (expiry, parse error, crash) classifies as ERR.

# to CMD...: run CMD under the per-probe deadline. Probes pass $TIMEOUT to the
# client's own timeout knob too; this is the backstop for clients that hang.
to() { timeout -k 3 "$((TIMEOUT + 5))" "$@"; }

have() { command -v "$1" >/dev/null 2>&1; }

# Only certificate-verification errors count as a correct rejection, and of
# those only TRUST failures: NOT_TRUST_RE (expiry, name mismatch) wins over
# CERT_RE and classifies as ERR, so e.g. Go's "x509: certificate has expired"
# or a hostname mismatch can never read as FIXED.
NOT_TRUST_RE='certificate has expired|certificate is expired|CERT_HAS_EXPIRED|not yet valid|CERT_NOT_YET_VALID|x509: certificate is valid for|ERR_TLS_CERT_ALTNAME_INVALID|Hostname mismatch|hostname mismatch|does not match target host|NotValidForName|no alternative certificate subject name matches|certificate subject name .* does not match|The certificate has expired|validity check failed'
CERT_RE='certificate verify failed|CERTIFICATE_VERIFY_FAILED|SSL certificate problem|unable to get local issuer|unable to get issuer|UNABLE_TO_GET_ISSUER_CERT|UNABLE_TO_VERIFY_LEAF_SIGNATURE|SELF_SIGNED_CERT_IN_CHAIN|CERT_UNTRUSTED|CERT_REVOKED|certificate is NOT trusted|PKI verification of server certificate failed|issuer is not known|x509: |failed to verify certificate|PKIX path|CertPathValidatorException|CertificateException|UnknownIssuer|invalid peer certificate|signed by unknown authority|unable to verify the first certificate|verify error:|Verify return code: [1-9]|server certificate verification failed|ERR_TLS_CERT|untrusted|distrusted|revoked|cannot verify .*certificate|SSLCertVerificationError|ssl certificate'
# rc=124/137: the backstop deadline in to() killed the probe.
NET_RE='^rc=(124|137)( |$)|Could not resolve|resolve host|Name or service not known|Temporary failure in name resolution|getaddrinfo|ENOTFOUND|EAI_AGAIN|dns error|No address associated|timed out|[Tt]imeout|TimeoutError|ETIMEDOUT|Connection refused|ECONNREFUSED|Network is unreachable|No route to host|ECONNRESET|connection reset|UnknownHostException|no such host|i/o timeout|CONNECT_TIMEOUT|UND_ERR_SOCKET'

# classify MODE RAWFILE -> one cell value.
#   live:    CONNECTED | CERT-FAIL | NET-ERR | ERR (incl. expiry / name mismatch)
#   offline: ACCEPTED  | REJECTED  | ERR
classify() {
  if [ "$1" = offline ]; then
    if grep -q '@@ACCEPTED@@' "$2"; then echo ACCEPTED
    elif grep -q '@@REJECTED@@' "$2"; then echo REJECTED
    else echo ERR; fi
    return
  fi
  if grep -q '@@CONNECTED@@' "$2"; then echo CONNECTED
  elif grep -Eqi -- "$NOT_TRUST_RE" "$2"; then echo ERR
  elif grep -Eqi -- "$CERT_RE" "$2"; then echo CERT-FAIL
  elif grep -Eq -- "$NET_RE" "$2"; then echo NET-ERR
  else echo ERR; fi
}

# ossl_verify_verdict OUTPUT: turn `openssl verify` output into the offline
# contract. Only the X509_V_ERR codes that mean "no trusted path" count as a
# rejection: 2 UNABLE_TO_GET_ISSUER_CERT, 18 DEPTH_ZERO_SELF_SIGNED,
# 19 SELF_SIGNED_CERT_IN_CHAIN, 20 UNABLE_TO_GET_ISSUER_CERT_LOCALLY,
# 27 CERT_UNTRUSTED, 28 CERT_REJECTED. Expiry (9/10) and the rest are ERR.
ossl_verify_verdict() {
  printf '%s\n' "$1" | grep -v '^$' | tail -3
  if printf '%s\n' "$1" | grep -q ': OK$'; then echo '@@ACCEPTED@@'
  elif printf '%s\n' "$1" | grep -Eq '^error (2|18|19|20|27|28) at '; then echo '@@REJECTED@@'
  fi
}

# ossl_verify_with CAFILE CAPATH CHAIN [EXTRA FLAGS...]: `openssl verify` the
# chain's leaf against exactly the given store ("-" = none for that half), at
# the profile's pinned instant. Never falls back to the default paths for a
# half that was not given, which is what a bare -CAfile would do.
ossl_verify_with() {
  local cafile=$1 capath=$2 chain=$3; shift 3
  local a=()
  if [ "$cafile" = - ]; then a+=(-no-CAfile); else a+=(-CAfile "$cafile"); fi
  if [ "$capath" = - ]; then a+=(-no-CApath); else a+=(-CApath "$capath"); fi
  to openssl verify -purpose sslserver -attime "$VERIFY_AT_EPOCH" -no-CAstore "${a[@]}" "$@" \
    -untrusted "$chain" "$chain" 2>&1
}

# json_str STRING: a JSON string literal.
json_str() {
  local s=$1
  s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//$'\t'/\\t}; s=${s//$'\r'/}; s=${s//$'\n'/\\n}
  printf '"%s"' "$s"
}

# ossl_union CHAIN CAFILE1 CAPATH1 [CAFILE2 CAPATH2 ...]: for clients that
# trust the UNION of several stores. Accepted if any store accepts, rejected
# only if every store rejects for a trust reason. Python-side verification
# flags (3.13+ create_default_context: -x509_strict -partial_chain) apply.
ossl_union() {
  local chain=$1 o v any_ok=0 all_rej=1; shift
  while [ $# -ge 2 ]; do
    o=$(ossl_verify_with "$1" "$2" "$chain" -x509_strict -partial_chain)
    v=$(ossl_verify_verdict "$o")
    echo "store cafile=$1 capath=$2:"; printf '%s\n' "$v" | sed 's/@@//g; s/^/  /'
    case $v in *@@ACCEPTED@@*) any_ok=1 ;; esac
    case $v in *@@REJECTED@@*) ;; *) all_rej=0 ;; esac
    shift 2
  done
  if [ $any_ok = 1 ]; then echo '@@ACCEPTED@@'; elif [ $all_rej = 1 ]; then echo '@@REJECTED@@'; fi
}

# marker_union OUTPUT...: combine sub-probe outputs for a client that trusts
# the union of several stores (ACCEPTED if any accepted, REJECTED only if all
# rejected). Sub-markers are defanged so only the combined marker counts.
marker_union() {
  local o any_ok=0 all_rej=1
  for o in "$@"; do
    printf '%s\n' "$o" | sed 's/@@//g; s/^/  /'
    case $o in *@@ACCEPTED@@*) any_ok=1 ;; esac
    case $o in *@@REJECTED@@*) ;; *) all_rej=0 ;; esac
  done
  if [ $any_ok = 1 ]; then echo '@@ACCEPTED@@'; elif [ $all_rej = 1 ]; then echo '@@REJECTED@@'; fi
}
