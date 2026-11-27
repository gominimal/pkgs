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
let util-linux = import "../util-linux/build.ncl" in
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
    # older; build.sh swaps in .NET 10.0.15, which also loads OpenSSL 4's
    # libssl.so.4.
    openssl,
    # flock: the wrappers' per-RUNNER_HOME setup lock (the kernel drops it when
    # its holder exits, so a killed start leaves no stale lock behind).
    util-linux,
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
              # The installed stamp marks the home current, so the wrapper
              # does not replace this stub home with the packaged runner.
              cp /usr/lib/actions-runner/.minimal-package-stamp rh/.minimal-installed-stamp
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
    # Runner.Worker (runs every job) and Runner.PluginHost (runs plugins) also
    # start on .NET 10 without their deps.json. Each is started with no
    # arguments: the host, CoreCLR and the app's assemblies load, its Main runs,
    # and it rejects the argument count (upstream ArgUtil.Equal, exit 1) with a
    # stack trace through GitHub.<app>.Program.Main. Pass = that trace and no
    # host or assembly-load error. Their runtimeconfig.json name no 8.x runtime.
    worker_and_pluginhost_start_on_dotnet10 =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              d=$(mktemp -d); cd "$d"
              # A home of its own: HostContext writes its trace under <home>/_diag.
              out=$(RUNNER_HOME=$d/r /usr/bin/actions-runner --version 2>&1) || { echo "$out" >&2; exit 1; }
              for app in Runner.Worker Runner.PluginHost; do
                rc=0; out=$(timeout 120 "$d/r/bin/$app" 2>&1) || rc=$?
                echo "$app: exit $rc"; head -n 4 <<<"$out"
                if [ "$rc" != 1 ]; then
                  echo "$app: want exit 1 (argument count rejected by its Main), got $rc:" >&2; echo "$out" >&2; exit 1
                fi
                if ! grep -q -F "GitHub.$app.Program.Main" <<<"$out" || ! grep -q -F ArgumentOutOfRangeException <<<"$out"; then
                  echo "$app: its Main did not run to the argument check:" >&2; echo "$out" >&2; exit 1
                fi
                if grep -q -E 'hostfxr|hostpolicy|FileNotFoundException|FileLoadException|TypeLoadException|BadImageFormatException|MissingMethodException|MissingFieldException' <<<"$out"; then
                  echo "$app: host or assembly-load error:" >&2; echo "$out" >&2; exit 1
                fi
                rcj=$d/r/bin/$app.runtimeconfig.json
                grep -q '"Microsoft.NETCore.App"' "$rcj"
                if grep -q '"version": "8\.' "$rcj"; then
                  echo "$app: runtimeconfig still names a .NET 8 runtime:" >&2; cat "$rcj" >&2; exit 1
                fi
                test ! -e "$d/r/bin/$app.deps.json"
                echo "$app: ok"
              done
            "%
          ],
        ],
      } | Test,
    # .NET 10 makes a real TLS connection through OpenSSL 4 (libssl.so.4; no
    # openssl-3.5 in the closure) and verifies the server against the system
    # store: SSL_CERT_FILE is our ca-certificates bundle with a throwaway CA
    # appended, i.e. the file .NET reads in place of /etc/ssl/cert.pem. The
    # sandbox cannot bind 443, and `config` drops the port from a GHES URL, so
    # this uses the runner's dev-service path (USE_DEV_ACTIONS_SERVICE_URL),
    # which connects to the URL as given: GET
    # https://127.0.0.1:18443/_apis/connectionData. The server is the bundled
    # node (it takes concurrent connections and any method), with a leaf signed
    # by that CA; it logs each decrypted request and answers 404. Pass = a
    # request reached the server and the runner saw the 404. Control: without
    # SSL_CERT_FILE no request may arrive, the runner reports a TLS failure, and
    # its diag log shows the certificate chain was refused.
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
              # Without SSL_CERT_FILE (the control, and a real runner) this libssl
              # reads OPENSSLDIR/cert.pem, i.e. the ca-certificates bundle below.
              openssl version -d | grep -q -x -F 'OPENSSLDIR: "/etc/ssl"'
              cat /etc/ssl/cert.pem ca.pem > bundle.pem
              echo "bundle: $(grep -c 'BEGIN CERTIFICATE' bundle.pem) certificates, the throwaway CA last"
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
              # .NET reads the whole bundle (every root, then the CA at the end).
              out=$(register rc-ok SSL_CERT_FILE="$d/bundle.pem")
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
              grep -r -h -o -m1 -E 'certificate chain: (PartialChain|UntrustedRoot)|RemoteCertificateChainErrors' "$d/rc-refuse/_diag" | head -1 || true
            "%
          ],
        ],
      } | Test,
    # actions-runner-config registers with --disableupdate as the last argument,
    # also when the caller passed `--disableupdate false` (a value upstream does
    # not read as the flag), and not for `remove` or help. Flags are whole
    # arguments: a value such as `--work "jobs --help"` is not a help flag. The
    # home lock is held while config.sh runs.
    config_wrapper_disables_update =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep, util-linux],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              d=$(mktemp -d); cd "$d"
              # A home that already holds this package's runner (so nothing is copied), with
              # a config.sh that prints each argument it receives on its own line.
              mkdir -p h/bin
              cp /usr/lib/actions-runner/.minimal-package-stamp h/.minimal-installed-stamp
              printf '#!/bin/bash\nfor a in "$@"; do echo "[$a]"; done\n' > h/config.sh
              chmod +x h/config.sh
              cfg() { RUNNER_HOME=$d/h /usr/bin/actions-runner-config "$@"; }
              check() { # check <name> last|none <args...>: --disableupdate is the last argument, or absent
                local name=$1 want=$2; shift 2
                local out; out=$(cfg "$@")
                if [ "$want" = last ]; then
                  if [ "$(tail -n 1 <<<"$out")" != '[--disableupdate]' ]; then
                    echo "$name: --disableupdate is not the last argument:" >&2; echo "$out" >&2; exit 1
                  fi
                elif grep -q -x -F '[--disableupdate]' <<<"$out"; then
                  echo "$name: --disableupdate was added:" >&2; echo "$out" >&2; exit 1
                fi
                echo "$name: ok ($want)"
              }
              check registration last --url https://github.com/o/r --token x
              check remove none remove --token x
              check remove-upper none REMOVE --token x
              check help none --help
              check help-upper none --HELP
              check help-slash none '/?'
              check short-help none -h
              check caller-chose last --url https://github.com/o/r --token x --disableupdate
              # Upstream reads `--disableupdate false` as an argument with a value, not
              # the flag, so the wrapper's flag still goes last.
              check caller-value last --url https://github.com/o/r --disableupdate false --token x
              # A flag inside a value is not a flag: `--work "jobs --help"` still registers.
              check help-in-a-value last --url https://github.com/o/r --token x --work "jobs --help"
              # The value reaches config.sh as one argument.
              # (A here-string, not a pipe: grep -q stopping early under pipefail can
              # fail the test with SIGPIPE.)
              out=$(cfg --url u --work "jobs --help"); grep -q -x -F '[jobs --help]' <<<"$out"
              # config.sh runs under the home lock (a concurrent start cannot rewrite a
              # .runner that `config.sh remove` deletes), and the lock is free after it.
              printf '#!/bin/bash\nif flock -n .minimal-setup.lock true; then echo lock-free; else echo lock-held; fi\n' > h/config.sh
              out=$(cfg remove --token x)
              if [ "$out" != lock-held ]; then echo "config.sh did not run under the home lock: $out" >&2; exit 1; fi
              flock -n h/.minimal-setup.lock true
              echo "config-under-lock: ok"
            "%
          ],
        ],
      } | Test,
    # actions-runner sets disableUpdate in the settings a start uses: inside a
    # jitconfig (the --jitconfig argument in any case, or
    # ACTIONS_RUNNER_INPUT_JITCONFIG in any case; the argument wins) and in an
    # existing .runner and .runner_migrated, keeping every other field. A
    # jitconfig it cannot read stops the start (control).
    self_update_off_at_start =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep, util-linux],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              d=$(mktemp -d); cd "$d"
              node=/usr/lib/actions-runner/externals/node24/bin/node
              # A home that already holds this package's runner, with a run.sh that prints
              # what the listener would read: the jitconfig after --jitconfig (option
              # name in any case), else from ACTIONS_RUNNER_INPUT_JITCONFIG in any case,
              # and the settings files in the home.
              mkdir -p h/bin
              cp /usr/lib/actions-runner/.minimal-package-stamp h/.minimal-installed-stamp
              cat > h/run.sh << 'STUB'
              #!/bin/bash
              node=/usr/lib/actions-runner/externals/node24/bin/node
              show() { "$node" -e 'const m = JSON.parse(Buffer.from(require("fs").readFileSync(0, "utf8").trim(), "base64").toString()); const r = JSON.parse(Buffer.from(m[".runner"], "base64").toString()); console.log("runner " + JSON.stringify(r)); console.log("credentials " + m[".credentials"]);' <<<"$1"; }
              shopt -s nocasematch
              cli=0
              while [ $# -gt 0 ]; do
                case "$1" in
                  --jitconfig) show "$2"; cli=1; shift 2 ;;
                  *) echo "arg [$1]"; shift ;;
                esac
              done
              if [ "$cli" = 0 ]; then
                while IFS= read -r -d '' kv; do
                  n=${kv%%=*}
                  if [[ $n == ACTIONS_RUNNER_INPUT_JITCONFIG ]]; then show "${!n}"; fi
                done < <(env -0)
              fi
              for f in .runner .runner_migrated; do
                if [ -f "$f" ]; then echo "file $f $(tr -d '\n ' < "$f")"; fi
              done
              if flock -n .minimal-setup.lock true; then echo "lock free"; else echo "lock held"; fi
              STUB
              chmod +x h/run.sh
              b64() { "$node" -e 'process.stdout.write(Buffer.from(process.argv[1]).toString("base64"))' "$1"; }
              runner=$(b64 '{"agentId":9,"agentName":"jit-1","ephemeral":true,"disableUpdate":false}')
              creds=$(b64 '{"scheme":"OAuth"}')
              blob=$(b64 "{\".runner\":\"$runner\",\".credentials\":\"$creds\"}")
              run() { RUNNER_HOME=$d/h /usr/bin/actions-runner "$@"; }
              expect() { # expect <output> <name>: the .runner seen by run.sh has updates off, the rest kept
                grep -q -F 'runner {"agentId":9,"agentName":"jit-1","ephemeral":true,"disableUpdate":true}' <<<"$1" \
                  || { echo "$2: updates not off, or .runner changed otherwise:" >&2; echo "$1" >&2; exit 1; }
                grep -q -F "credentials $creds" <<<"$1" || { echo "$2: .credentials changed" >&2; exit 1; }
                echo "$2: ok"
              }
              expect "$(run --jitconfig "$blob" --once)" jitconfig-arg
              # run.sh (and so the listener) starts with the home lock released, or a
              # running runner would block every later start.
              out=$(run --once); grep -q -x -F 'lock free' <<<"$out"
              # Upstream keeps the first --jitconfig value and ignores a later one, so
              # only the first is rewritten and an unreadable duplicate does not stop
              # the start.
              out=$(run --jitconfig "$blob" --JITCONFIG not-base64-json 2>&1) || { echo "jitconfig-duplicate: the start failed:" >&2; echo "$out" >&2; exit 1; }
              expect "$out" jitconfig-duplicate
              expect "$(run --JITCONFIG "$blob")" jitconfig-arg-upper
              expect "$(ACTIONS_RUNNER_INPUT_JITCONFIG=$blob run)" jitconfig-env
              expect "$(env actions_runner_input_jitconfig="$blob" RUNNER_HOME="$d/h" /usr/bin/actions-runner)" jitconfig-env-lower
              # The argument wins, as in the listener: an unreadable variable beside it
              # does not stop the start.
              expect "$(ACTIONS_RUNNER_INPUT_JITCONFIG=not-base64-json run --jitconfig "$blob")" jitconfig-arg-over-env
              out=$(run --jitconfig "$blob" --once); grep -q -x -F 'arg [--once]' <<<"$out"
              # The listener does not read --jitconfig=<value>, so the wrapper passes it on as it is.
              out=$(run "--jitconfig=$blob")
              grep -q -x -F "arg [--jitconfig=$blob]" <<<"$out" || { echo "--jitconfig= was changed:" >&2; echo "$out" >&2; exit 1; }
              echo "jitconfig-equals: passed on unchanged"
              # A home registered before this package (updates on) is switched off at start,
              # in .runner and in the migrated settings the listener tries first.
              printf '\xef\xbb\xbf{"agentId": 7, "disableUpdate": false, "serverUrl": "https://example.invalid"}' > h/.runner
              printf '{"agentId": 7, "disableUpdate": false, "serverUrl": "https://migrated.example.invalid"}' > h/.runner_migrated
              chmod 640 h/.runner
              out=$(run)
              grep -q -x -F 'file .runner {"agentId":7,"disableUpdate":true,"serverUrl":"https://example.invalid"}' <<<"$out" \
                || { echo "existing .runner: updates not off:" >&2; echo "$out" >&2; exit 1; }
              grep -q -x -F 'file .runner_migrated {"agentId":7,"disableUpdate":true,"serverUrl":"https://migrated.example.invalid"}' <<<"$out" \
                || { echo "existing .runner_migrated: updates not off:" >&2; echo "$out" >&2; exit 1; }
              # The rewrite keeps the file's mode and leaves no temporary file behind.
              test "$(stat -c %a h/.runner)" = 640
              if ls -A h | grep -q '^\.\.runner'; then
                echo "a temporary settings file was left in the home:" >&2; ls -A h >&2; exit 1
              fi
              echo "existing-settings-files: ok"
              rm h/.runner h/.runner_migrated
              # A rewrite whose write fails refuses the start and leaves .runner
              # unchanged and no temporary file. A file size limit of 0 makes the
              # write fail with EFBIG after the temporary file is created (SIGXFSZ
              # is ignored, so node sees the error instead of being killed).
              printf '{"agentId": 7, "disableUpdate": false}' > h/.runner
              before=$(sha256sum < h/.runner)
              if out=$( (trap '' XFSZ; ulimit -f 0; run) 2>&1); then
                echo "control failed: a .runner rewrite that could not be written started the runner" >&2; echo "$out" >&2; exit 1
              fi
              grep -q 'Could not set disableUpdate in .*/\.runner' <<<"$out" || { echo "$out" >&2; exit 1; }
              grep -q EFBIG <<<"$out" || { echo "$out" >&2; exit 1; }
              test "$(sha256sum < h/.runner)" = "$before"
              if ls -A h | grep -q '^\.\.runner'; then
                echo "a temporary settings file was left in the home after a failed write:" >&2; ls -A h >&2; exit 1
              fi
              rm h/.runner
              echo "failed-write: refused, nothing left behind"
              # Fail closed: a number a JS rewrite would change (agentId above
              # 2^53) refuses the start and leaves .runner byte-identical.
              printf '{"agentId": 9007199254740993, "disableUpdate": false}' > h/.runner
              before=$(sha256sum < h/.runner)
              if out=$(run 2>&1); then
                echo "control failed: a .runner with an unsafe integer was rewritten and started" >&2; echo "$out" >&2; exit 1
              fi
              grep -q 'Could not set disableUpdate in .*/\.runner' <<<"$out"
              grep -q '9007199254740993' <<<"$out"
              if grep -q '^file ' <<<"$out"; then
                echo "control failed: run.sh started after the refusal" >&2; echo "$out" >&2; exit 1
              fi
              test "$(sha256sum < h/.runner)" = "$before"
              rm h/.runner
              echo "unsafe-integer-runner-file: refused, unchanged"
              big=$(b64 '{"agentId":9007199254740993,"disableUpdate":false}')
              if out=$(run --jitconfig "$(b64 "{\".runner\":\"$big\"}")" 2>&1); then
                echo "control failed: a jitconfig with an unsafe integer started the runner" >&2; echo "$out" >&2; exit 1
              fi
              grep -q '9007199254740993' <<<"$out"
              if grep -q '^runner ' <<<"$out"; then
                echo "control failed: run.sh started after the refusal" >&2; echo "$out" >&2; exit 1
              fi
              echo "unsafe-integer-jitconfig: refused"
              # Fail closed: a jitconfig the wrapper cannot read stops the start before
              # run.sh, from the argument and from the variable.
              if out=$(run --jitconfig not-base64-json 2>&1); then
                echo "control failed: an unreadable jitconfig started the runner" >&2; echo "$out" >&2; exit 1
              fi
              grep -q 'Could not set disableUpdate in the jitconfig from --jitconfig' <<<"$out"
              if grep -q '^arg ' <<<"$out"; then
                echo "control failed: run.sh started after the refusal" >&2; echo "$out" >&2; exit 1
              fi
              if out=$(env Actions_Runner_Input_JitConfig=not-base64-json RUNNER_HOME="$d/h" /usr/bin/actions-runner 2>&1); then
                echo "control failed: an unreadable jitconfig variable started the runner" >&2; echo "$out" >&2; exit 1
              fi
              grep -q 'Could not set disableUpdate in the jitconfig from Actions_Runner_Input_JitConfig' <<<"$out"
              echo "unreadable-jitconfig: refused"
            "%
          ],
        ],
      } | Test,
    # A RUNNER_HOME an older package set up (no stamp, its own bin/) is upgraded to
    # the packaged runner at the next start, keeping .runner, .credentials, .env
    # and _work, and the upgraded runner starts. A current home is left alone. A
    # home an upstream self-update rearranged, and one whose copy was
    # interrupted (with or without the package's stamp installed), are upgraded
    # again, also when started from inside the home. Controls: a home whose
    # runner is still running, one another process works in, and a directory
    # with a bin/ that holds no runner, are not changed.
    home_upgrade_keeps_registration =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep, util-linux],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              d=$(mktemp -d); cd "$d"
              pkg=/usr/lib/actions-runner
              same() { # same <a> <b>: identical content (diffutils' cmp is not in this closure)
                [ "$(sha256sum < "$1")" = "$(sha256sum < "$2")" ] || { echo "differs: $1 $2" >&2; return 1; }
              }
              # A RUNNER_HOME as an older package left it: its own bin/ and externals/, an
              # upstream self-update leftover, a registration and work data, no stamp.
              mkdir -p h/bin h/externals/node20 h/bin.2.330.0 h/externals.2.330.0 h/_work/r h/_diag
              # A self-update leftover holds a runner; a person's bin.* or externals.*
              # beside it does not, and is kept.
              echo old-listener > h/bin.2.330.0/Runner.Listener
              mkdir -p h/bin.bak h/externals.zip; echo mine > h/bin.bak/tool; echo mine > h/externals.zip/f
              echo old-listener > h/bin/Runner.Listener
              echo old > h/externals/node20/marker
              # Registration files in upstream's formats: HostContext parses .runner
              # (RunnerSettings) and .credentials (CredentialData) as JSON at every
              # start, --version included (LoadDefaultUserAgents).
              printf '{"agentId": 7, "agentName": "n", "poolId": 1, "poolName": "Default", "serverUrl": "https://pipelines.example.invalid/x", "gitHubUrl": "https://github.com/o/r", "workFolder": "_work", "disableUpdate": false}' > h/.runner
              printf '{"scheme": "OAuth", "data": {"clientId": "kept-marker-0b7e", "authorizationUrl": "https://vstoken.example.invalid/x", "requireFipsCryptography": "False"}}' > h/.credentials
              echo keep > h/_work/r/file
              echo 'LANG=C.UTF-8 # kept-marker-env' > h/.env
              out=$(RUNNER_HOME=$d/h /usr/bin/actions-runner --version 2>&1) || { echo "$out" >&2; exit 1; }
              echo "$out"
              grep -q 'Upgrading the runner in' <<<"$out"
              same h/bin/Runner.Listener "$pkg/bin/Runner.Listener"
              same h/externals/node24/bin/node "$pkg/externals/node24/bin/node"
              test ! -e h/externals/node20/marker
              test ! -e h/bin.2.330.0 && test ! -e h/externals.2.330.0
              test "$(cat h/bin.bak/tool)" = mine && test "$(cat h/externals.zip/f)" = mine
              test ! -e h/.minimal-copying
              # The setup lock is released (flock; the file itself stays).
              flock -n h/.minimal-setup.lock true
              same h/.minimal-installed-stamp "$pkg/.minimal-package-stamp"
              grep -q '"clientId": "kept-marker-0b7e"' h/.credentials
              test "$(cat h/_work/r/file)" = keep
              grep -q kept-marker-env h/.env
              grep -q '"agentId": 7' h/.runner
              grep -q '"disableUpdate": true' h/.runner
              # The upgraded runner starts: run.sh -> Runner.Listener --version on .NET 10.
              grep -q -E '^[0-9]+\.[0-9]+\.[0-9]+$' <<<"$out"
              # A second start finds the stamp current and copies nothing.
              echo marker > h/bin/local-marker
              out=$(RUNNER_HOME=$d/h /usr/bin/actions-runner --version 2>&1)
              if grep -q 'Upgrading the runner' <<<"$out"; then
                echo "a current home was upgraded again:" >&2; echo "$out" >&2; exit 1
              fi
              test -e h/bin/local-marker
              echo "upgrade: ok"
              # A home an upstream self-update rearranged (bin -> bin.<version>, as
              # update.sh leaves it) is upgraded again although its stamp matches.
              mv h/bin h/bin.2.999.0; ln -s "$d/h/bin.2.999.0" h/bin
              out=$(RUNNER_HOME=$d/h /usr/bin/actions-runner --version 2>&1) || { echo "$out" >&2; exit 1; }
              grep -q 'Upgrading the runner in' <<<"$out"
              test -d h/bin && test ! -L h/bin && test ! -e h/bin.2.999.0
              same h/bin/Runner.Listener "$pkg/bin/Runner.Listener"
              echo "self-updated-home: upgraded"
              # A copy that was interrupted (marker left, no bin/Runner.Listener yet) is
              # done again at the next start.
              mkdir -p p/bin; echo partial > p/bin/partial; : > p/.minimal-copying
              out=$(RUNNER_HOME=$d/p /usr/bin/actions-runner --version 2>&1) || { echo "$out" >&2; exit 1; }
              same p/bin/Runner.Listener "$pkg/bin/Runner.Listener"
              test ! -e p/bin/partial && test ! -e p/.minimal-copying
              same p/.minimal-installed-stamp "$pkg/.minimal-package-stamp"
              echo "interrupted-copy: redone"
              # The same with the package's stamp already installed (a copy into a
              # set-up home that failed after creating bin/): .minimal-copying
              # outweighs the stamp.
              mkdir -p q/bin; echo partial > q/bin/partial; : > q/.minimal-copying
              cp "$pkg/.minimal-package-stamp" q/.minimal-installed-stamp
              out=$(RUNNER_HOME=$d/q /usr/bin/actions-runner --version 2>&1) || { echo "interrupted-copy-stamped: the start failed:" >&2; echo "$out" >&2; exit 1; }
              same q/bin/Runner.Listener "$pkg/bin/Runner.Listener"
              test ! -e q/bin/partial && test ! -e q/.minimal-copying
              echo "interrupted-copy-stamped: redone"
              # Control: an outdated home another process works in (here a sleep
              # whose working directory is the home, as run.sh's is while a start
              # that found the home current has not yet started the listener) is
              # not replaced.
              mkdir -p w/bin; echo old-listener > w/bin/Runner.Listener
              (cd w && exec sleep 60) & wpid=$!
              trap 'kill $wpid 2>/dev/null || true' EXIT
              sleep 1
              if out=$(RUNNER_HOME=$d/w /usr/bin/actions-runner --version 2>&1); then
                echo "control failed: the wrapper replaced the runner in a home another process works in" >&2; echo "$out" >&2; exit 1
              fi
              grep -q "A process is still working in $d/w (PID $wpid," <<<"$out" || { echo "$out" >&2; exit 1; }
              test "$(cat w/bin/Runner.Listener)" = old-listener && flock -n w/.minimal-setup.lock true
              kill $wpid; wait $wpid 2>/dev/null || true
              echo "home-in-use: refused, unchanged"
              # A start from a shell whose working directory is the home is not
              # in its own way.
              mkdir -p i/bin; echo old-listener > i/bin/Runner.Listener
              out=$(cd i && RUNNER_HOME=$d/i /usr/bin/actions-runner --version 2>&1) || { echo "start-from-home: the start failed:" >&2; echo "$out" >&2; exit 1; }
              grep -q 'Upgrading the runner in' <<<"$out"
              same i/bin/Runner.Listener "$pkg/bin/Runner.Listener"
              echo "start-from-home: upgraded"
              # Control: a directory with a bin/ that holds no runner (RUNNER_HOME=$HOME
              # with a ~/bin) is refused and nothing in it changes.
              mkdir -p u/bin u/bin.old; echo mine > u/bin/tool; echo mine > u/bin.old/tool
              if out=$(RUNNER_HOME=$d/u /usr/bin/actions-runner --version 2>&1); then
                echo "control failed: the wrapper took over a directory that holds no runner" >&2; echo "$out" >&2; exit 1
              fi
              grep -q 'no runner (no bin/Runner.Listener)' <<<"$out"
              test "$(cat u/bin/tool)" = mine && test "$(cat u/bin.old/tool)" = mine
              test ! -e u/run.sh && test ! -e u/.minimal-installed-stamp && test ! -e u/.minimal-setup.lock
              echo "unrelated-bin: refused, unchanged"
              # A directory with only a bin.* and an externals.* that hold no runner
              # (a person's bin.old, externals.zip) is set up, and they survive the
              # first start and every later one: they do not make the home outdated,
              # so the second start upgrades nothing and deletes nothing.
              mkdir -p v/bin.old v/externals.zip; echo mine > v/bin.old/tool; echo mine > v/externals.zip/f
              out=$(RUNNER_HOME=$d/v /usr/bin/actions-runner --version 2>&1) || { echo "bin-dot-only: the first start failed:" >&2; echo "$out" >&2; exit 1; }
              out=$(RUNNER_HOME=$d/v /usr/bin/actions-runner --version 2>&1) || { echo "bin-dot-only: the second start failed:" >&2; echo "$out" >&2; exit 1; }
              if grep -q 'Upgrading the runner' <<<"$out"; then
                echo "bin-dot-only: a bin.* without a runner made the home outdated:" >&2; echo "$out" >&2; exit 1
              fi
              test "$(cat v/bin.old/tool)" = mine && test "$(cat v/externals.zip/f)" = mine
              same v/bin/Runner.Listener "$pkg/bin/Runner.Listener"
              echo "bin-dot-only: kept"
              # Control: a runner still running from an outdated home is not replaced. bash
              # copied in as bin/Runner.Listener stands in for it (/proc/<pid>/exe).
              # The loop keeps that bash alive as itself: `-c 'sleep 60'` would exec
              # sleep in its place (bash's single-command exec), and the process would
              # no longer be bin/Runner.Listener.
              mkdir -p r/bin
              cp "$(command -v bash)" r/bin/Runner.Listener
              r/bin/Runner.Listener -c 'while :; do sleep 1; done' & pid=$!
              trap 'kill $pid 2>/dev/null || true' EXIT
              sleep 1
              # The stand-in really is a process running bin/Runner.Listener.
              stand_in=$(readlink /proc/$pid/exe)
              echo "stand-in: $stand_in"
              test "$stand_in" = "$(cd r/bin && pwd -P)/Runner.Listener"
              if out=$(RUNNER_HOME=$d/r /usr/bin/actions-runner --version 2>&1); then
                echo "control failed: the wrapper replaced the bin/ of a running runner" >&2; echo "$out" >&2; exit 1
              fi
              grep -q "is still running (PID $pid)" <<<"$out"
              same r/bin/Runner.Listener "$(command -v bash)"
              test ! -e r/.minimal-installed-stamp && flock -n r/.minimal-setup.lock true
              echo "running-runner: refused"
              # A relative RUNNER_HOME is the directory relative to where the start
              # was made, before and after the wrapper moves into it.
              mkdir rel-start
              out=$(cd rel-start && RUNNER_HOME=rel /usr/bin/actions-runner --version 2>&1) || { echo "relative-home: the start failed:" >&2; echo "$out" >&2; exit 1; }
              same rel-start/rel/bin/Runner.Listener "$pkg/bin/Runner.Listener"
              test ! -e rel-start/rel/rel
              grep -q -E '^[0-9]+\.[0-9]+\.[0-9]+$' <<<"$out"
              echo "relative-home: ok"
            "%
          ],
        ],
      } | Test,
    # A RUNNER_HOME the wrapper cannot set up is refused at once, with a message
    # that names a next step, instead of waited on: a home it cannot write to,
    # a directory where the setup lock file goes, an unset RUNNER_HOME and one
    # that cannot be created. The unwritable home is /proc, which root cannot
    # create files in either (chmod does not stop root, and the sandbox may run
    # the test as root). A start waits while another process holds the home's
    # flock, and goes ahead once that holder is killed: the kernel releases the
    # lock, so there is no stale lock to recover.
    home_setup_refusals =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep, util-linux],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              d=$(mktemp -d); cd "$d"
              refused() { # refused <name> <expected message> <RUNNER_HOME, or "unset">: a non-zero exit within 30 s, with the message
                local name=$1 want=$2 home=$3 out rc=0
                if [ "$home" = unset ]; then
                  out=$(env -u RUNNER_HOME timeout 30 /usr/bin/actions-runner --version 2>&1) || rc=$?
                else
                  out=$(RUNNER_HOME=$home timeout 30 /usr/bin/actions-runner --version 2>&1) || rc=$?
                fi
                if [ "$rc" = 0 ] || [ "$rc" = 124 ]; then
                  echo "$name: exit $rc, want a prompt refusal (124: still running after 30 s):" >&2; echo "$out" >&2; exit 1
                fi
                if ! grep -q -F "$want" <<<"$out"; then
                  echo "$name: the message does not say '$want':" >&2; echo "$out" >&2; exit 1
                fi
                echo "$name: refused (exit $rc)"
              }
              refused unwritable-home "Could not create or open the lock file /proc/.minimal-setup.lock (the error is above). Fix the permissions in /proc," /proc
              test ! -e /proc/.minimal-setup.lock
              mkdir -p rd/.minimal-setup.lock
              refused directory-lock "or remove $d/rd/.minimal-setup.lock if it is not a regular file, then start again." "$d/rd"
              test -z "$(ls -A rd/.minimal-setup.lock)" && test ! -e rd/run.sh
              refused unset "RUNNER_HOME is not set. Set RUNNER_HOME to an empty directory or to a runner directory, then start again." unset
              : > file
              refused uncreatable "Could not create the runner directory $d/file/home (the error is above). Set RUNNER_HOME to an empty directory or to a runner directory, then start again." "$d/file/home"
              # While another process holds the home's lock, a start waits and changes
              # nothing. The holder is a sleep that inherited the locked descriptor,
              # so killing it is the whole holder.
              mkdir c
              bash -c 'exec 9>>c/.minimal-setup.lock; flock 9; exec sleep 120' >/dev/null 2>&1 & holder=$!
              trap 'kill -9 $holder 2>/dev/null || true' EXIT
              for _ in $(seq 100); do flock -n c/.minimal-setup.lock true 2>/dev/null || break; sleep 0.1; done
              if flock -n c/.minimal-setup.lock true; then echo "contended: the holder never took the lock" >&2; exit 1; fi
              rc=0; out=$(RUNNER_HOME=$d/c timeout 5 /usr/bin/actions-runner --version 2>&1) || rc=$?
              if [ "$rc" != 124 ]; then
                echo "contended: want the start still waiting after 5 s (exit 124), got exit $rc:" >&2; echo "$out" >&2; exit 1
              fi
              test ! -e c/run.sh
              # It says that it waits, so the wait does not look like a stall.
              grep -q -F "Waiting for another actions-runner or actions-runner-config to release $d/c/.minimal-setup.lock" <<<"$out" \
                || { echo "contended: no waiting line:" >&2; echo "$out" >&2; exit 1; }
              echo "contended: waited"
              # SIGKILL runs no cleanup in the holder; the kernel drops its lock and
              # the next start goes ahead.
              kill -9 "$holder"; wait "$holder" 2>/dev/null || true
              out=$(RUNNER_HOME=$d/c timeout 300 /usr/bin/actions-runner --version 2>&1) || { echo "killed-holder: the start failed:" >&2; echo "$out" >&2; exit 1; }
              test -x c/run.sh
              flock -n c/.minimal-setup.lock true
              echo "killed-holder: lock released, start went ahead"
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
