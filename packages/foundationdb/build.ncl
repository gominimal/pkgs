let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in
let boost = import "../boost/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let git = import "../git/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let mono = import "../mono/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let patch = import "../patch/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "7.3.81" in
{
  name = "foundationdb",

  build_deps = [
    { file = "build.sh" } | Local,
    # OpenSSL 4 port (const X509 accessors); build.sh applies it with hash checks.
    # Drop when upstream supports OpenSSL 4.
    { file = "foundationdb-7.3.81-openssl4.patch" } | Local,
    {
      url = "https://github.com/apple/foundationdb/archive/refs/tags/%{version}.tar.gz",
      sha256 = "27cb330913378637de778334f117ea567f91a74e07877225d4bbf6d32547d1d9",
      extract = true,
      strip_prefix = "foundationdb-%{version}",
    } | Source,
    base,
    boost,
    cmake,
    git,
    mono,
    ninja,
    # OpenSSL 4. Upstream FDB 7.3 does not compile against it; the carried patch and a
    # Boost define in build.sh fix that (upstream apple/foundationdb#14348 pins 3.5
    # instead). build.sh checks the result links libssl.so.4 and nothing links .so.3.
    openssl,
    patch,
    pkgconf,
    python,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    openssl,
    subsetOf gcc ["libgcc", "libstdcpp"],
    zlib,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  needs = {
    internet = {},
    dns = {},
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/libfdb_c*.so*" } | OutputLib,
    includes = { glob = "usr/include/foundationdb/**" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/FoundationDB-Client/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/foundationdb-client.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "apple",
        repo = "foundationdb",
      },
      build_cost_multiple = 4,
    } | Attrs,

  tests = {
    version_check = standaloneTest "/bin/fdbcli --version",

    server_smoke =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
            set -euo pipefail

            # Create a minimal FDB cluster file
            BASE=$(pwd)
            CLUSTER_FILE="$BASE/fdb.cluster"
            DATA_DIR="$BASE/data"
            LOG_DIR="$BASE/logs"
            mkdir -p "$DATA_DIR" "$LOG_DIR"

            echo "test:testid@127.0.0.1:4500" > "$CLUSTER_FILE"

            # Start fdbserver in the background
            /bin/fdbserver \
              -p auto:4500 \
              -C "$CLUSTER_FILE" \
              -d "$DATA_DIR" \
              -L "$LOG_DIR" &
            SERVER_PID=$!

            # Wait for server to start
            sleep 2

            # Configure the database as a new single-process cluster
            /bin/fdbcli -C "$CLUSTER_FILE" --exec "configure new single memory"

            # Wait for database to be ready
            sleep 1

            # Write and read back a key
            /bin/fdbcli -C "$CLUSTER_FILE" --exec "writemode on; set testkey testvalue"
            RESULT=$(/bin/fdbcli -C "$CLUSTER_FILE" --exec "get testkey")

            # Verify result contains the value
            echo "$RESULT" | grep -q "testvalue"

            # Clean shutdown
            kill $SERVER_PID
            wait $SERVER_PID 2>/dev/null || true

            echo "FoundationDB smoke test passed"
          "%
          ],
        ],
      } | Test,

    # FDB's own unit tests for the libcrypto paths that OpenSSL 4 could change:
    # PEM/DER key round trips through EVP + OSSL_PARAM (JsonWebKeySet, keys from
    # MkCert's generator) and ES256 JWT sign/verify (TokenSign). The unittests
    # role prints "Found N tests" and counts a pattern that matches nothing as a
    # failure, so neither can pass vacuously.
    crypto_unittests =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
            set -euo pipefail
            mkdir -p ut && cd ut
            for pattern in /fdbrpc/JsonWebKeySet /fdbrpc/TokenSign/JWT; do
              out=$(/bin/fdbserver -r unittests -f "$pattern" 2>&1) || { echo "$out"; exit 1; }
              echo "$out"
              echo "$out" | grep -qE '^Found [1-9][0-9]* tests$'
              echo "$out" | grep -qE '^1 tests passed; 0 tests failed\.$'
            done
            echo "FoundationDB crypto unit tests passed"
          "%
          ],
        ],
      } | Test,

    # TLS end to end on loopback against OpenSSL 4, through the code the OpenSSL 4
    # patch touches: the server's peer-rule matcher (check_verify / match_*), which
    # must accept a client cert whose CN matches the rule, refuse one from the same
    # CA whose CN does not (rule mismatch), and refuse one from an untrusted CA
    # (chain verification). The refusals are checked in the server's trace log by
    # their reason, not only by the client failing.
    tls_loopback =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep, openssl],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
            set -euo pipefail
            BASE=$(pwd)/tls
            mkdir -p "$BASE/data" "$BASE/logs"
            cd "$BASE"

            # name, CN, signing CA cert, signing CA key
            leaf() {
              openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
                -keyout "$1.key" -out "$1.pem" -days 2 -subj "/CN=$2" \
                -CA "$3" -CAkey "$4" \
                -addext basicConstraints=critical,CA:FALSE \
                -addext keyUsage=critical,digitalSignature \
                -addext extendedKeyUsage=serverAuth,clientAuth \
                -addext subjectAltName=IP:127.0.0.1
            }
            ca() {
              openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
                -keyout "$1.key" -out "$1.pem" -days 2 -subj "/CN=$2" \
                -addext basicConstraints=critical,CA:TRUE \
                -addext keyUsage=critical,keyCertSign,cRLSign \
                -addext subjectKeyIdentifier=hash
            }
            ca ca fdb-test-ca
            ca rogue-ca fdb-test-ca
            leaf server fdb-test ca.pem ca.key
            leaf client fdb-test ca.pem ca.key
            leaf intruder fdb-intruder ca.pem ca.key
            leaf rogue fdb-test rogue-ca.pem rogue-ca.key

            echo "test:testid@127.0.0.1:4520:tls" > fdb.cluster

            /bin/fdbserver -p 127.0.0.1:4520:tls -C fdb.cluster -d data -L logs \
              --tls-certificate-file server.pem --tls-key-file server.key --tls-ca-file ca.pem \
              --tls-verify-peers 'Check.Valid=1,S.CN=fdb-test' &
            SERVER_PID=$!
            trap 'kill $SERVER_PID 2>/dev/null || true' EXIT

            cli() { # cert name, then fdbcli --exec command
              timeout 30 /bin/fdbcli -C fdb.cluster --timeout 10 \
                --tls-certificate-file "$1.pem" --tls-key-file "$1.key" --tls-ca-file ca.pem \
                --tls-verify-peers 'Check.Valid=1,S.CN=fdb-test' --exec "$2" 2>&1 || true
            }

            sleep 2
            ok=0
            for _ in $(seq 1 30); do
              st=$(cli client "status minimal")
              if echo "$st" | grep -q '^The database is available\.$'; then ok=1; break; fi
              # Harmless once the database exists; retried until the server is up.
              cli client "configure new single memory"
              sleep 2
            done
            [ "$ok" = 1 ] || { echo "$st"; echo "FAIL: trusted client never saw the database available" >&2; exit 1; }
            cli client "writemode on; set tlskey tlsvalue"
            got=$(cli client "get tlskey")
            echo "$got"
            echo "$got" | grep -q "tlsvalue"

            # policy: refused AND the server logged why. Trace files are flushed
            # asynchronously, so poll for the event.
            refused() { # cert name, expected Reason
              out=$(cli "$1" "status minimal")
              echo "$out"
              if echo "$out" | grep -q '^The database is available'; then
                echo "FAIL: $1 cert was accepted" >&2; exit 1
              fi
              for _ in $(seq 1 30); do
                if grep -h 'Type="TLSPolicyFailure"' logs/*.xml 2>/dev/null | grep -qF "Reason=\"$2\""; then
                  echo "refused $1: $2"; return 0
                fi
                sleep 1
              done
              echo "FAIL: no TLSPolicyFailure Reason=\"$2\" for $1" >&2
              grep -h 'TLSPolicyFailure' logs/*.xml >&2 || true
              exit 1
            }
            refused intruder "Cert subject match failure"
            refused rogue "preverification failed"

            echo "FoundationDB TLS loopback test passed"
          "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
