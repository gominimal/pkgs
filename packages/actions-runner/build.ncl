let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let bash = import "../bash/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let grep = import "../grep/build.ncl" in
let icu = import "../icu/build.ncl" in
let jq = import "../jq/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "2.338.2" in

let { amd64_sha256, arm64_sha256 } = {
  amd64_sha256 = "baebf204307bac6193480852732f0aba2ae97b6c5597c244f4d5558390147c40",
  arm64_sha256 = "670adb2f268fe21dcbb58b3db0e0aa9d5b3bddfe2c651481336e561ff86de945",
}
in

# The .NET runtime the runner runs on (see build.sh): Microsoft's portable
# linux build. 10.0.15 is the first that loads OpenSSL 4 (dotnet/runtime#135534).
# sha256 of the files whose sha512 matches Microsoft's
# release-metadata/10.0/releases.json.
let dotnet_version = "10.0.15" in
let { dotnet_amd64_sha256, dotnet_arm64_sha256 } = {
  dotnet_amd64_sha256 = "6fd6f9029008e0985271f3bd285de9efe249e38438cd2ea431e3f8a5b2420815",
  dotnet_arm64_sha256 = "1e963b7c51de5fd51fbd8b7059a8e5b7c19351f46fc5cea8723adf2e458cf4b1",
}
in

{
  name = "actions-runner",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "gs://minimal-staging-archives/actions/runner/actions-runner-linux-x64-%{version}.tar.gz",
          sha256 = amd64_sha256,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "gs://minimal-staging-archives/actions/runner/actions-runner-linux-arm64-%{version}.tar.gz",
          sha256 = arm64_sha256,
        } | Source,
    } target,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://builds.dotnet.microsoft.com/dotnet/Runtime/%{dotnet_version}/dotnet-runtime-%{dotnet_version}-linux-x64.tar.gz",
          sha256 = dotnet_amd64_sha256,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://builds.dotnet.microsoft.com/dotnet/Runtime/%{dotnet_version}/dotnet-runtime-%{dotnet_version}-linux-arm64.tar.gz",
          sha256 = dotnet_arm64_sha256,
        } | Source,
    } target,
    base,
    binutils, # readelf: the no-OpenSSL-3 check in build.sh
    jq, # reads the runner's deps.json / runtimeconfig.json
  ],
  # CVE-2026-111943: the wrappers export NODE_OPTIONS=--use-openssl-ca, so the
  # bundled externals/node{20,24} trust ca-certificates (OpenSSL's default
  # store, OPENSSLDIR=/etc/ssl) instead of their compiled-in roots, which still
  # hold emSign ECC Root CA - G3. The .NET listener already used OpenSSL's store.
  #
  # Not done by swapping externals/node* for our node-lts: the runner mounts
  # externals/ into job containers at /__e and runs actions with
  # /__e/node24/bin/node there, so a symlink would dangle inside the container
  # and our node (linked against our glibc) would not run in it anyway.
  # Container jobs keep the bundled node and the container image's store,
  # unchanged. node20 is kept for the same reason: the runner still selects it
  # for an action declaring `using: node20` when the job opts out of the
  # node24 default (ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION); the flag covers
  # it too.
  runtime_deps = [
    bash,
    ca-certificates,
    coreutils, # the wrappers `cp -a` the runner into a fresh RUNNER_HOME
    glibc,
    grep, # upstream config.sh checks for ICU with `ldconfig -NXv | grep libicu` and exits if grep fails
    icu,
    # .NET dlopens libssl: upstream's bundled .NET 8 knew only libssl.so.3 and
    # older (hence openssl-3.5 until now); build.sh swaps in .NET 10.0.15, which
    # also loads OpenSSL 4's libssl.so.4.
    openssl,
    zlib,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
    include dotnet_version,
  },

  outputs = {
    config = { glob = "usr/bin/actions-runner-config" } | OutputBin,
    run = { glob = "usr/bin/actions-runner" } | OutputBin,
    runner = { glob = "usr/lib/actions-runner/**", allow_executable = true } | OutputData,
  },

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          ["/bin/bash", "-c", "test -x /usr/bin/actions-runner"],
          # --help's exit status is not the point, but the wrapper's setup is. One
          # command: each cmd gets a fresh /tmp, so a separate `test -x` sees nothing.
          ["/bin/bash", "-c", "RUNNER_HOME=/tmp/runner /usr/bin/actions-runner --help || true; test -x /tmp/runner/run.sh"],
          # The config wrapper runs upstream config.sh's dependency checks (ldd, ldconfig,
          # grep) before anything else; a tool missing from the closure fails them.
          ["/bin/bash", "-c", "out=$(RUNNER_HOME=/tmp/rc RUNNER_ALLOW_RUNASROOT=1 /usr/bin/actions-runner-config --help 2>&1); echo \"$out\"; [[ $out != *'is missing'* && $out != *'Can not find'* && -x /tmp/rc/config.sh ]]"],
        ],
      } | Test,
    # CVE-2026-111943: under the wrapper, the bundled node trusts the system
    # store, not its compiled-in roots. A throwaway CA is added to a copy of
    # ca-certificates and handed over with SSL_CERT_FILE (OpenSSL's override);
    # only a node reading OpenSSL's store can then verify a local server whose
    # leaf that CA signed. Control: the same node outside the wrapper refuses it.
    bundled_node_uses_system_store =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, openssl, coreutils],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              d=$(mktemp -d); cd "$d"
              openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -keyout ca.key -out ca.pem -days 2 -subj /CN=throwaway-test-ca 2>/dev/null
              openssl req -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -keyout leaf.key -out leaf.csr -subj /CN=localhost 2>/dev/null
              printf 'subjectAltName=DNS:localhost,IP:127.0.0.1
basicConstraints=CA:FALSE
extendedKeyUsage=serverAuth
' > leaf.ext
              openssl x509 -req -in leaf.csr -CA ca.pem -CAkey ca.key -CAcreateserial -days 1 -extfile leaf.ext -out leaf.pem 2>/dev/null
              cat /etc/ssl/cert.pem ca.pem > bundle.pem
              openssl s_server -accept 127.0.0.1:18443 -cert leaf.pem -key leaf.key -www -quiet & srv=$!
              trap 'kill $srv 2>/dev/null || true' EXIT
              sleep 1
              # A RUNNER_HOME whose run.sh just runs its arguments, so the
              # wrapper's environment reaches the bundled node as it would.
              mkdir -p rh/bin; ln -s /usr/lib/actions-runner/externals rh/externals
              printf '#!/bin/bash
exec "$@"
' > rh/run.sh; chmod +x rh/run.sh
              js="require('https').get('https://127.0.0.1:18443/', (r) => { console.log('ok', r.statusCode); process.exit(0) }).on('error', (e) => { console.log('refused', e.code); process.exit(1) })"
              for n in node20 node24; do
                echo "$n via wrapper:"
                RUNNER_HOME=$d/rh SSL_CERT_FILE=$d/bundle.pem /usr/bin/actions-runner "externals/$n/bin/node" -e "$js"
                echo "$n without wrapper (must refuse):"
                if SSL_CERT_FILE=$d/bundle.pem "/usr/lib/actions-runner/externals/$n/bin/node" -e "$js"; then
                  echo "control failed: bundled $n trusted the system store without the wrapper" >&2; exit 1
                fi
              done
            "%
          ],
        ],
      } | Test,
    # The runner's .NET runs on .NET 10 (build.sh) and starts: the host, CoreCLR
    # and the runner's net8.0 assemblies load together.
    listener_starts_on_dotnet10 =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          ["/bin/bash", "-c", "set -e; RUNNER_HOME=/tmp/r /usr/bin/actions-runner --help >/dev/null 2>&1 || true; v=$(/tmp/r/bin/Runner.Listener --version); echo \"$v\"; [[ $v =~ ^[0-9]+\\.[0-9]+\\.[0-9]+$ ]]; grep -q '\"Microsoft.NETCore.App\"' /tmp/r/bin/Runner.Listener.runtimeconfig.json; ! grep -q '\"version\": \"8\\.' /tmp/r/bin/Runner.Listener.runtimeconfig.json"],
        ],
      } | Test,
    # .NET 10 makes a real TLS connection through OpenSSL 4 (libssl.so.4; no
    # openssl-3.5 in the closure) and verifies the server against the system
    # store. The sandbox cannot bind 443, and `config` drops the port from a
    # GHES URL, so this uses the runner's dev-service path
    # (USE_DEV_ACTIONS_SERVICE_URL), which connects to the URL as given:
    # GET https://127.0.0.1:18443/_apis/connectionData. The server is the
    # bundled node (it takes concurrent connections and any method), with a
    # leaf signed by a throwaway CA that SSL_CERT_FILE names; it logs each
    # decrypted request and answers 404. Pass = a request reached the server.
    # Control: without SSL_CERT_FILE no request may arrive, and the runner's
    # diag log must show it refused the certificate.
    dotnet_tls_via_openssl4 =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, openssl, coreutils, grep],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              d=$(mktemp -d); cd "$d"; export HOME=$d
              openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -keyout ca.key -out ca.pem -days 2 -subj /CN=throwaway-test-ca 2>/dev/null
              openssl req -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -keyout leaf.key -out leaf.csr -subj /CN=127.0.0.1 2>/dev/null
              printf 'subjectAltName=IP:127.0.0.1\nbasicConstraints=CA:FALSE\nextendedKeyUsage=serverAuth\n' > leaf.ext
              openssl x509 -req -in leaf.csr -CA ca.pem -CAkey ca.key -CAcreateserial -days 1 -extfile leaf.ext -out leaf.pem 2>/dev/null
              openssl version
              js="const fs=require('fs'),log=(s)=>fs.appendFileSync(process.env.LOG,s+'\n');
                const srv=require('https').createServer({key:fs.readFileSync('leaf.key'),cert:fs.readFileSync('leaf.pem')},(q,r)=>{log('REQUEST '+q.method+' '+q.url);r.writeHead(404,{'Content-Length':'0',Connection:'close'});r.end()});
                srv.on('tlsClientError',(e)=>log('TLSERROR '+e.message));
                srv.listen(18443,'127.0.0.1',()=>log('LISTENING'))"
              node=/usr/lib/actions-runner/externals/node24/bin/node
              srv=
              trap 'kill $srv 2>/dev/null || true' EXIT
              serve() { # serve <log>: start the server, wait until it listens
                : > "$1"
                LOG=$d/$1 "$node" -e "$js" & srv=$!
                for _ in $(seq 50); do grep -q LISTENING "$1" && return 0; sleep 0.2; done
                echo "server did not start" >&2; cat "$1"; exit 1
              }
              # The runner masks its token everywhere in _diag, so it must be a
              # string no assertion below could contain (`t` masked every "t").
              token=QZXJ7VKW2
              register() { # register <home> [env...]: one unattended configure against the dev-service URL
                local home=$1; shift
                env "$@" USE_DEV_ACTIONS_SERVICE_URL=1 RUNNER_HOME="$d/$home" RUNNER_ALLOW_RUNASROOT=1 timeout 90 /usr/bin/actions-runner-config --unattended --url https://127.0.0.1:18443/o/r --token "$token" --name n 2>&1 || true
              }

              serve ok.log
              diag() { # the runner's own record of what went wrong, inner exceptions included
                echo "--- runner diag ($1):"
                grep -rh -E -B1 -A4 'Exception|SSL|[Cc]ertificate|[Cc]hain|libssl' "$d/$1/_diag" | head -150 || true
              }
              # SSL_CERT_FILE names only the throwaway CA: .NET reads it as its
              # whole root store, with no system bundle to parse first.
              out=$(register rc-ok SSL_CERT_FILE="$d/ca.pem")
              echo "$out"; echo "--- server:"; cat ok.log
              if [[ $out == *'No usable version of libssl'* ]] || ! grep -q '^REQUEST GET /' ok.log || [[ $out != *'Not Found'* ]]; then
                diag rc-ok; exit 1
              fi
              kill $srv; wait $srv 2>/dev/null || true

              serve refuse.log
              out=$(register rc-refuse)
              echo "control:"; echo "$out"; echo "--- server:"; cat refuse.log
              # Each of the three fails if TLS were accepted: a request would
              # reach the server, the console would show the 404 instead, and
              # _diag would hold no chain error.
              if grep -q '^REQUEST' refuse.log; then
                echo "control failed: a request reached the server, the runner trusted a CA outside the system store" >&2; exit 1
              fi
              if [[ $out != *'SSL connection could not be established'* ]]; then
                echo "control failed: the runner did not report a TLS failure" >&2; diag rc-refuse; exit 1
              fi
              if ! grep -r -q -E 'PartialChain|UntrustedRoot|RemoteCertificateChainErrors' "$d/rc-refuse/_diag"; then
                echo "control failed: no certificate-chain refusal in the runner diag" >&2; diag rc-refuse; exit 1
              fi
              grep -r -h -o -m1 -E 'certificate chain: (PartialChain|UntrustedRoot)|RemoteCertificateChainErrors' "$d/rc-refuse/_diag" | head -1
            "%
          ],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      env_state_wiring = {
        env_var = "RUNNER_HOME",
        prefix = "actions-runner",
      },
      source_provenance = {
        category = 'GithubRepo,
        owner = "actions",
        repo = "runner",
      },
    } | Attrs,
} | BuildSpec
