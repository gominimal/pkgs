let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let llvm = import "../llvm/build.ncl" in
let rust = import "../rust/build.ncl" in
let go = import "../go/build.ncl" in
let python = import "../python/build.ncl" in
let ruby = import "../ruby/build.ncl" in
let perl = import "../perl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let make = import "../make/build.ncl" in
let git = import "../git/build.ncl" in
let curl = import "../curl/build.ncl" in
let automake = import "../automake/build.ncl" in
let libtool = import "../libtool/build.ncl" in
let unzip = import "../unzip/build.ncl" in
let patch = import "../patch/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in
let openssl = import "../openssl/build.ncl" in

let version = "1.3.14" in
let dl_base = "https://github.com/oven-sh/bun/releases/download/bun-v%{version}" in
let { amd64_sha256, arm64_sha256 } = {
  amd64_sha256 = "951ee2aee855f08595aeec6225226a298d3fea83a3dcd6465c09cbccdf7e848f",
  arm64_sha256 = "a27ffb63a8310375836e0d6f668ae17fa8d8d18b88c37c821c65331973a19a3b",
}
in
{
  name = "bun",
  build_deps = [
    { file = "build.sh" } | Local,
    # CVE-2026-111943: drops the three emSign roots NSS 3.131.1 removed from
    # bun's compiled-in root store. See the patch header; drop it on the first
    # bun release containing oven-sh/bun#46159.
    { file = "cve-2026-111943-remove-emsign-roots.patch" } | Local,
    # Trust the system CA store instead of the compiled-in roots by default
    # (gominimal/pkgmgr-rs#1026). See the patch header and build.sh.
    { file = "system-ca-store-default.patch" } | Local,
    {
      url = "https://github.com/oven-sh/bun/archive/refs/tags/bun-v%{version}.tar.gz",
      sha256 = "112a5915992807f04b183854d360c2bf87ac7c1587fb5da3c560bdbb75b8c92e",
      extract = true,
      strip_prefix = "bun-bun-v%{version}",
    } | Source,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "%{dl_base}/bun-linux-x64.zip",
          sha256 = amd64_sha256,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "%{dl_base}/bun-linux-aarch64.zip",
          sha256 = arm64_sha256,
        } | Source,
    } target,
    base,
    toolchain,
    cmake,
    ninja,
    llvm,
    rust,
    go,
    python,
    ruby,
    perl,
    pkgconf,
    make,
    git,
    curl,
    automake,
    libtool,
    unzip,
    patch,
  ],
  runtime_deps = [
    glibc,
    git,
    bash, # the /usr/bin wrappers are #!/bin/sh scripts (bash provides bin/sh)
    # bun trusts the system CA store by default (system-ca-store-default.patch).
    # Without it bun falls back to its compiled-in roots, so declare it.
    ca-certificates,
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    bun = { glob = "usr/bin/bun" } | OutputBin,
    bunx = { glob = "usr/bin/bunx" } | OutputBin,
    bash_completion = { glob = "usr/share/bash-completion/completions/bun" } | OutputData,
    fish_completion = { glob = "usr/share/fish/vendor_completions.d/bun.fish" } | OutputData,
    zsh_completion = { glob = "usr/share/zsh/site-functions/_bun" } | OutputData,
    libexec = { glob = "usr/libexec/bun/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      env_state_wiring = {
        env_var = "BUN_INSTALL_CACHE_DIR",
        prefix = "bun-cache",
      },
      source_provenance = {
        category = 'GithubRepo,
        owner = "oven-sh",
        repo = "bun",
      },
      build_cost_multiple = 2,
    } | Attrs,

  tests = {
    # The raw ELF, not the /usr/bin wrapper: standaloneTest runs with no shell
    # in the sandbox, so a #!/bin/sh wrapper would ENOENT there.
    smoketest = standaloneTest "/usr/libexec/bun/bun --version",

    eval =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "bun --eval 'console.log(1+1)' | grep -q '^2$'"],
        ],
      } | Test,
    # CVE-2026-111943: the compiled-in store (tls.rootCertificates) must not
    # carry the three emSign roots the patch removes, matched by SHA-256 of the
    # DER, with at least 100 roots so an empty store cannot pass.
    emsign_roots_removed =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              cat > /tmp/emsign.js <<'JS'
              const { X509Certificate, createHash } = require("node:crypto");
              const { rootCertificates } = require("node:tls");
              const removed = [
                "86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b",
                "125609aa301da0a249b97a8239cb6a34216f44dcac9f3954b14292f2e8c8608f",
                "bc4d809b15189d78db3e1d8cf4f9726a795da1643ca5f1358e1ddb0edc0d7eb3",
              ];
              const fps = new Set(rootCertificates.map(p => createHash("sha256").update(new X509Certificate(p).raw).digest("hex")));
              const left = removed.filter(h => fps.has(h));
              if (fps.size < 100 || left.length) { console.log(`roots=${fps.size} still bundled: ${left}`); process.exit(1); }
              JS
              bun /tmp/emsign.js
            "%
          ],
        ],
      } | Test,
    # system-ca-store-default.patch: by default bun trusts the system store
    # (ca-certificates) INSTEAD of its compiled-in roots; NODE_USE_SYSTEM_CA=0
    # and --use-bundled-ca give upstream's store back. Offline, one bun process
    # per mode (bun builds its store once per process), checked through
    # tls.connect against local `openssl s_server`s.
    #
    # What builds the store (bun-v1.3.14 us_get_default_ca_store(), BoringSSL
    # 0c5fce43). Every mode, stock or patched, first calls
    # X509_STORE_set_default_paths: all of $SSL_CERT_FILE (else
    # /etc/ssl/cert.pem) plus <subject-hash>.N lookups in $SSL_CERT_DIR (else
    # /etc/ssl/certs). On Minimal that IS the ca-certificates store, so a CA
    # named by SSL_CERT_FILE is trusted in every mode and cannot tell modes
    # apart (pkgs#1134 review). On top of that:
    #   - patched default: bun's own system loader (only $SSL_CERT_FILE /
    #     $SSL_CERT_DIR when either is set, else ca-certificates.crt and the
    #     *.crt/*.pem files under /etc/ssl/certs, ...). The compiled-in roots
    #     are added only when that loader finds nothing.
    #   - opt-outs, = upstream's store: the compiled-in roots, not the loader.
    #     The system store is still trusted, through the default paths above.
    # tls.getCACertificates('default') cannot check any of this: it is built
    # in JS (src/js/node/tls.ts) and always lists the compiled-in roots.
    #
    # Probes. R, C and S each get a FORGED issuer: a self-signed copy of the
    # real root (same subject) under our own key, which signs a 127.0.0.1 leaf
    # with no authorityKeyIdentifier. BoringSSL looks the leaf's issuer up by
    # name. If the real root is in the store it is found, the leaf's signature
    # fails against its key, and the result is CERT_SIGNATURE_FAILURE ("in").
    # If it is not, the result is UNABLE_TO_VERIFY_LEAF_SIGNATURE or
    # UNABLE_TO_GET_ISSUER_CERT_LOCALLY ("out"). No real root key is needed.
    #   R  DigiCert Global Root CA: compiled in, NOT in ca-certificates
    #   C  ISRG Root X1: in both (control: the oracle can say "in")
    #   S  Telia RSA TLS Root CA v3: in ca-certificates only
    #   T  a throwaway CA that signs a real leaf ("ok" = trusted). It sits only
    #      at $SSL_CERT_DIR/testca.pem, a name bun's loader reads but
    #      BoringSSL's hash-dir lookup never opens, and SSL_CERT_FILE stays unset.
    # roots.js asserts R/C/S membership from bun's own lists first, so a
    # ca-certificates update that adds R or drops S fails loudly here.
    #
    #   env                            mode                   expect
    #   real store                     default                R=out C=in S=in
    #   real store                     NODE_USE_SYSTEM_CA=0   R=in  C=in S=in
    #   real store                     --use-bundled-ca       R=in  C=in S=in
    #   SSL_CERT_DIR=<dir with T>      default                T=ok
    #   SSL_CERT_DIR=<dir with T>      NODE_USE_SYSTEM_CA=0   T=out
    #   SSL_CERT_DIR=<dir with T>      --use-bundled-ca       T=out
    #   empty file + empty dir         default (fallback)     R=in  S=out
    #
    # Which rows catch which wrong bun:
    #   - Unpatched bun-v1.3.14 trusts the compiled-in roots by default and
    #     skips the loader: default gives R=in and T=out, so BOTH default rows
    #     fail.
    #   - A union patch (system roots on top of the compiled-in ones on the
    #     default path, e.g. --use-system-ca on by default): R=in fails the
    #     real-store default row. If it only flips Arguments.zig's default,
    #     NODE_USE_SYSTEM_CA=0 still merges the loader, so T=ok also fails
    #     that row.
    #   - A patch that drops the compiled-in roots and never puts them back:
    #     R=out fails both opt-out rows and the fallback row.
    #   The opt-out and fallback rows pass on unpatched bun BY DESIGN: there
    #   the patch promises upstream's store exactly. Their job is the last
    #   case, not the first two.
    system_ca_store_default =
      {
        class = 'Standalone,
        test_deps = [base, ca-certificates, openssl],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              test -s /etc/ssl/certs/ca-certificates.crt
              test -s /etc/ssl/cert.pem
              d=$(mktemp -d)
              cd "$d"
              mkdir sys empty
              : > none.pem
              clean() {
                env -u SSL_CERT_FILE -u SSL_CERT_DIR -u NODE_USE_SYSTEM_CA -u NODE_EXTRA_CA_CERTS \
                  -u HTTPS_PROXY -u https_proxy -u HTTP_PROXY -u http_proxy -u ALL_PROXY -u all_proxy "$@"
              }

              # The probe roots, taken from bun's own lists. In this env (no
              # SSL_CERT_*) 'system' is bun's loader reading ca-certificates.
              cat > roots.js <<'JS'
              const { X509Certificate, createHash } = require("node:crypto");
              const tls = require("node:tls");
              const fp = p => createHash("sha256").update(new X509Certificate(p).raw).digest("hex");
              const bundled = new Map(tls.rootCertificates.map(p => [fp(p), p]));
              const system = new Map(tls.getCACertificates("system").map(p => [fp(p), p]));
              // name: [DER sha256, compiled in, in ca-certificates]
              const probes = {
                R: ["4348a0e9444c78cb265e058d5e8944b4d84f9662bd26db257f8934a443c70161", true, false],
                C: ["96bcec06264976f37460779acf28c5a7cfe8a3c0aae11a8ffcee05c0bddf08c6", true, true],
                S: ["d13db1294c45ebc6fc86c6bbf69fa29bdfe692dff7c713c243c7a956c6a2284c", false, true],
              };
              if (bundled.size < 100 || system.size < 100) { console.log(`bundled=${bundled.size} system=${system.size}`); process.exit(1); }
              for (const [name, [h, inBundled, inSystem]] of Object.entries(probes)) {
                if (bundled.has(h) !== inBundled || system.has(h) !== inSystem) {
                  console.log(`${name}: compiled in=${bundled.has(h)} system=${system.has(h)}, want ${inBundled}/${inSystem}`);
                  process.exit(1);
                }
                require("node:fs").writeFileSync(`${name}.pem`, (bundled.get(h) ?? system.get(h)).trim() + "\n");
              }
              JS
              clean bun roots.js
              # R must also be absent by NAME (a same-subject root would be found).
              openssl crl2pkcs7 -nocrl -certfile /etc/ssl/cert.pem | openssl pkcs7 -print_certs -noout > sys.subjects
              if grep -qxF "$(openssl x509 -in R.pem -noout -subject)" sys.subjects ||
                 ls /etc/ssl/certs/"$(openssl x509 -in R.pem -noout -subject_hash)".* >/dev/null 2>&1; then
                echo "R's subject is in the system store; pick another compiled-in-only root" >&2; exit 1
              fi

              openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out fake.key 2>/dev/null
              openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out leaf.key 2>/dev/null
              openssl req -new -key leaf.key -subj "/CN=127.0.0.1" -out leaf.csr 2>/dev/null
              printf '%s\n' subjectAltName=IP:127.0.0.1 basicConstraints=CA:FALSE \
                keyUsage=digitalSignature,keyEncipherment extendedKeyUsage=serverAuth \
                authorityKeyIdentifier=none > leaf.cnf
              n=0
              for p in R C S; do
                n=$((n + 1))
                openssl x509 -in "$p.pem" -key fake.key -days 2 -out "fake$p.pem"
                openssl x509 -req -in leaf.csr -CA "fake$p.pem" -CAkey fake.key -set_serial "$n" -days 2 \
                  -extfile leaf.cnf -out "$p.leaf.pem" 2>/dev/null
                iss=$(openssl x509 -in "$p.leaf.pem" -noout -issuer)
                sub=$(openssl x509 -in "$p.pem" -noout -subject)
                [ "${iss#issuer=}" = "${sub#subject=}" ] || { echo "$p: leaf issuer '$iss' != root '$sub'" >&2; exit 1; }
                if openssl x509 -in "$p.leaf.pem" -noout -text | grep -q 'Authority Key Identifier'; then
                  echo "$p: leaf carries an authorityKeyIdentifier" >&2; exit 1
                fi
              done
              openssl req -x509 -newkey rsa:2048 -nodes -days 2 -subj "/CN=minimal test CA" \
                -keyout ca.key -out sys/testca.pem 2>/dev/null
              openssl x509 -req -in leaf.csr -CA sys/testca.pem -CAkey ca.key -set_serial 9 -days 2 \
                -extfile leaf.cnf -out T.leaf.pem 2>/dev/null

              # One server per probe. -no-CA* keeps s_server from appending a
              # chain from its own store: the client must see the leaf alone.
              base=$(( 20000 + RANDOM % 20000 ))
              pids=""
              trap 'kill $pids 2>/dev/null || true' EXIT
              i=0
              for p in R C S T; do
                openssl s_server -accept "127.0.0.1:$((base + i))" -cert "$p.leaf.pem" -key leaf.key \
                  -no-CAfile -no-CApath -no-CAstore -www -quiet >/dev/null 2>&1 &
                pids="$pids $!"
                eval "port_$p=$((base + i))"
                i=$((i + 1))
              done
              for p in R C S T; do
                eval "port=\$port_$p"
                for _ in $(seq 100); do (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null && break; sleep 0.1; done
              done

              # Prints e.g. "R=out C=in": ok = trusted, in/out = the forged
              # issuer's real root is / is not in the store, else the raw code.
              cat > check.js <<'JS'
              const tls = require("node:tls");
              const IN = ["CERT_SIGNATURE_FAILURE"];
              const OUT = ["UNABLE_TO_VERIFY_LEAF_SIGNATURE", "UNABLE_TO_GET_ISSUER_CERT_LOCALLY"];
              const one = (name, port) => new Promise(r => {
                const s = tls.connect({ host: "127.0.0.1", port });
                s.on("secureConnect", () => { s.destroy(); r(`${name}=ok`); });
                s.on("error", e => {
                  const c = String(e.code);
                  r(`${name}=` + (IN.includes(c) ? "in" : OUT.includes(c) ? "out" : c));
                });
              });
              (async () => {
                const out = [];
                for (const a of process.argv.slice(2)) { const [n, p] = a.split(":"); out.push(await one(n, +p)); }
                console.log(out.join(" "));
                process.exit(0);
              })();
              setTimeout(() => { console.log("timeout"); process.exit(3); }, 20000).unref();
              JS
              real="R:$port_R C:$port_C S:$port_S"
              fails=0
              expect() {
                want=$1; label=$2; shift 2
                got=$("$@" 2>&1 || true)
                echo "$label: $got"
                [ "$got" = "$want" ] || { echo "  FAIL: want '$want'" >&2; fails=$((fails + 1)); }
              }
              expect "R=out C=in S=in" "real store, default" clean bun check.js $real
              expect "R=in C=in S=in" "real store, NODE_USE_SYSTEM_CA=0" clean NODE_USE_SYSTEM_CA=0 bun check.js $real
              expect "R=in C=in S=in" "real store, --use-bundled-ca" clean bun --use-bundled-ca check.js $real
              expect "T=ok" "SSL_CERT_DIR=sys, default" clean SSL_CERT_DIR="$d/sys" bun check.js "T:$port_T"
              expect "T=out" "SSL_CERT_DIR=sys, NODE_USE_SYSTEM_CA=0" \
                clean SSL_CERT_DIR="$d/sys" NODE_USE_SYSTEM_CA=0 bun check.js "T:$port_T"
              expect "T=out" "SSL_CERT_DIR=sys, --use-bundled-ca" \
                clean SSL_CERT_DIR="$d/sys" bun --use-bundled-ca check.js "T:$port_T"
              expect "R=in S=out" "empty system store, default" \
                clean SSL_CERT_FILE="$d/none.pem" SSL_CERT_DIR="$d/empty" bun check.js "R:$port_R" "S:$port_S"
              [ "$fails" -eq 0 ] || { echo "$fails CA-store check(s) failed" >&2; exit 1; }
            "%
          ],
        ],
      } | Test,
    # `bun add -g` lands a package's bin in ~/.local/bin, where the session
    # PATH resolves it, backed by a global dir outside the cache
    # (gominimal/inbox#584).
    global_install =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              # Standalone tests run with the build-sandbox env (HOME=/state/home,
              # no ~/.local/bin on PATH), so each lookup below spells out a
              # session-like PATH that carries ~/.local/bin.
              mkdir -p /tmp/g/bin && cd /tmp/g
              printf '%s' '{"name":"gbin","version":"1.0.0","bin":{"gbin":"bin/gbin"}}' > package.json
              printf '#!/bin/sh\necho ok\n' > bin/gbin && chmod +x bin/gbin
              cd / && bun add -g file:/tmp/g
              test "$(PATH=/usr/bin:/bin:$HOME/.local/bin command -v gbin)" = "$HOME/.local/bin/gbin"
              test "$(PATH=/usr/bin:/bin:$HOME/.local/bin gbin)" = ok
              test -f "$HOME/.local/share/bun/global/package.json"

              # A caller's BUN_INSTALL keeps bun's own <BUN_INSTALL>/bin layout.
              test "$(BUN_INSTALL=/tmp/bi bun --eval 'console.log(process.env.BUN_INSTALL_BIN ?? "unset")')" = unset
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
