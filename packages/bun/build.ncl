let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in
let bash = import "../bash/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let nasm = import "../nasm/build.ncl" in
let llvm-23 = import "../llvm-23/build.ncl" in
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

let version = "1.4.4" in
let dl_base = "https://github.com/oven-sh/bun/releases/download/bun-v%{version}" in
let { amd64_sha256, arm64_sha256 } = {
  amd64_sha256 = "bf8ccbfb2b0b80159e0f9a6d15c55317add8077534dbc6130a3edb52fccb395c",
  arm64_sha256 = "baa6bb36f51d6e58561e02bbea825038a9df454f673d6d776e8bbf86f8c7850e",
}
in
{
  name = "bun",
  build_deps = [
    { file = "build.sh" } | Local,
    # Trust the system CA store instead of the compiled-in roots by default
    # (gominimal/pkgmgr-rs#1026). See the patch header and build.sh.
    { file = "system-ca-store-default.patch" } | Local,
    {
      url = "https://github.com/oven-sh/bun/archive/refs/tags/bun-v%{version}.tar.gz",
      sha256 = "00ce37fa5ac393a7d225bcf847365982fceb818b56a19b6884fefd67918468ff",
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
    # bun 1.4 assembles libjpeg-turbo's x86_64 SIMD (.asm) with nasm
    # (scripts/build/deps/libjpeg-turbo.ts); compile.ts asserts "nasm not found in
    # toolchain" at the use site. Only x64 builds use it; declared on both arches.
    nasm,
    # bun 1.4.x's configure accepts only clang / ld.lld of the pinned release series
    # (scripts/build/ci-images/spec.ts pins.llvm 23.1.1; tools.ts LLVM_VERSION_RANGE
    # >=23.1.0 <23.1.99) and searches /usr/lib/llvm-23/bin, so it builds on the prefixed
    # llvm-23 (pkgs#1057). It also refuses a rustc whose LLVM major differs from clang's
    # (config.ts): rust is built on the default llvm, also 23 today. When the default llvm
    # moves to 24, bun moves with it or rust's LLVM has to stay 23.
    llvm-23,
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
        test_deps = [bash-bootstrap, grep],
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
        test_deps = [bash-bootstrap, coreutils],
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
    # What builds the store (bun-v1.4.4 us_get_default_ca_store()). Every mode,
    # stock or patched, adds what X509_STORE_set_default_paths would: all of
    # $SSL_CERT_FILE (else /etc/ssl/cert.pem) plus <subject-hash>.N lookups in
    # $SSL_CERT_DIR (else /etc/ssl/certs). On Minimal that IS the ca-certificates store, so a CA
    # named by SSL_CERT_FILE is trusted in every mode and cannot tell modes
    # apart (pkgs#1134 review). On top of that:
    #   - patched default: bun's own system loader (src/runtime/socket/
    #     system_certs.rs: $SSL_CERT_FILE, else the default file and the
    #     well-known bundles; $SSL_CERT_DIR, else the default dir and the
    #     well-known dirs such as /etc/ssl/certs). The compiled-in roots
    #     are added only when that loader finds nothing.
    #   - opt-outs, = upstream's store: the compiled-in roots, not the loader.
    #     The system store is still trusted, through the default paths above.
    # tls.getCACertificates('default') cannot check any of this: it is built
    # in JS (src/js/node/tls.ts) and always lists the compiled-in roots.
    #
    # Probes are CONSTRUCTED, not taken from real differences between the two
    # stores. Up to bun-v1.3.14 we used a compiled-in-only root (DigiCert Global
    # Root CA) and a ca-certificates-only one (Telia RSA TLS Root CA v3), but
    # bun-v1.4.4's compiled-in roots (packages/bun-usockets/root_certs.der, 118)
    # are exactly ca-certificates 2026.11.05's 118: both follow the same NSS
    # release, so no real root tells them apart, and any later NSS or bun bump
    # can open or close that gap again. So the store under test is built here:
    #   sysx.pem  = /etc/ssl/certs/ca-certificates.crt minus R (by DER sha256),
    #               plus S. The "system store" rows run with SSL_CERT_FILE=sysx.pem
    #               and SSL_CERT_DIR=<empty dir>: with both set, bun's loader
    #               (us_load_system_certificates_posix) reads only those, and
    #               so do the default paths, so /etc/ssl is out of the picture.
    #   R  a compiled-in RSA root other than C, whose subject no other root in
    #      either list shares, picked from tls.rootCertificates (lowest DER
    #      sha256, so stable for a given bun). Compiled in, NOT in sysx.pem by
    #      construction.
    #   C  ISRG Root X1: compiled in and in sysx.pem (control: the oracle can
    #      say "in").
    #   S  a throwaway CA that signs a real leaf ("ok" = trusted), only in
    #      sysx.pem: the system-only probe.
    #   T  a throwaway CA that signs a real leaf. It sits only at
    #      $SSL_CERT_DIR/testca.pem, a name bun's loader reads but BoringSSL's
    #      hash-dir lookup never opens, and SSL_CERT_FILE stays unset.
    # R and C get a FORGED issuer: a self-signed copy of the real root (same
    # subject) under our own key, which signs a 127.0.0.1 leaf with no
    # authorityKeyIdentifier. BoringSSL looks the leaf's issuer up by name. If
    # the real root is in the store it is found, the leaf's signature fails
    # against its key, and the result is CERT_SIGNATURE_FAILURE ("in"). If it
    # is not, the result is UNABLE_TO_VERIFY_LEAF_SIGNATURE or
    # UNABLE_TO_GET_ISSUER_CERT_LOCALLY ("out"). No real root key is needed.
    # Sanity checks fail the test (not a row) if R is not in
    # tls.rootCertificates, if R's DER or subject is in sysx.pem, or if bun's
    # own tls.getCACertificates('system') under the sysx env holds R or lacks
    # C or S.
    #
    #   env                            mode                   expect
    #   sysx file + empty dir          default                R=out C=in S=ok
    #   sysx file + empty dir          NODE_USE_SYSTEM_CA=0   R=in  C=in S=ok
    #   sysx file + empty dir          --use-bundled-ca       R=in  C=in S=ok
    #   sysx file + empty dir          --use-openssl-ca       R=out C=in S=ok
    #   sysx file + empty dir          --use-openssl-ca and   R=out C=in S=ok
    #                                  NODE_USE_SYSTEM_CA=
    #                                  0/false/no/off
    #   SSL_CERT_DIR=<dir with T>      default                T=ok
    #   SSL_CERT_DIR=<dir with T>      NODE_USE_SYSTEM_CA=0   T=out
    #   SSL_CERT_DIR=<dir with T>      --use-bundled-ca       T=out
    #   empty file + empty dir         default (fallback)     R=in  S=out
    #
    # Which rows catch which wrong bun:
    #   - Unpatched bun-v1.4.4 trusts the compiled-in roots by default and
    #     skips the loader: default gives R=in and T=out, so the sysx and
    #     SSL_CERT_DIR default rows BOTH fail.
    #   - A union patch (system roots on top of the compiled-in ones on the
    #     default path, e.g. --use-system-ca on by default): R=in fails the
    #     sysx default row. If it only flips the CLI flag's default,
    #     NODE_USE_SYSTEM_CA=0 still merges the loader, so T=ok also fails
    #     that row.
    #   - A patch that drops the compiled-in roots and never puts them back:
    #     R=out fails both opt-out rows and the fallback row.
    #   - A patch that lets the NODE_USE_SYSTEM_CA opt-out override an
    #     explicit --use-openssl-ca: R=in fails the openssl rows with the
    #     opt-out set.
    #   - A patch that keeps upstream's dedup of the OpenSSL default file
    #     against the compiled-in roots while leaving those roots out:
    #     C=out fails every openssl row (C is in both, so no store has it).
    #   The opt-out and fallback rows pass on unpatched bun BY DESIGN: there
    #   the patch promises upstream's store exactly. Their job is the last
    #   case, not the first two.
    system_ca_store_default =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, ca-certificates, openssl, coreutils, grep],
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

              openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out fake.key 2>/dev/null
              openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out leaf.key 2>/dev/null
              openssl req -new -key leaf.key -subj "/CN=127.0.0.1" -out leaf.csr 2>/dev/null
              printf '%s\n' subjectAltName=IP:127.0.0.1 basicConstraints=CA:FALSE \
                keyUsage=digitalSignature,keyEncipherment extendedKeyUsage=serverAuth \
                authorityKeyIdentifier=none > leaf.cnf
              # S: system-only (goes into sysx.pem). T: SSL_CERT_DIR-only.
              openssl req -x509 -newkey rsa:2048 -nodes -days 2 -subj "/CN=minimal test system CA" \
                -keyout sca.key -out sca.pem 2>/dev/null
              openssl x509 -req -in leaf.csr -CA sca.pem -CAkey sca.key -set_serial 8 -days 2 \
                -extfile leaf.cnf -out S.leaf.pem 2>/dev/null
              openssl req -x509 -newkey rsa:2048 -nodes -days 2 -subj "/CN=minimal test CA" \
                -keyout ca.key -out sys/testca.pem 2>/dev/null
              openssl x509 -req -in leaf.csr -CA sys/testca.pem -CAkey ca.key -set_serial 9 -days 2 \
                -extfile leaf.cnf -out T.leaf.pem 2>/dev/null

              # Pick R from bun's compiled-in roots and build sysx.pem (see the
              # comment above the test). Writes R.pem, C.pem, sysx.pem.
              cat > roots.js <<'JS'
              const { X509Certificate, createHash } = require("node:crypto");
              const tls = require("node:tls");
              const fs = require("node:fs");
              const fp = p => createHash("sha256").update(new X509Certificate(p).raw).digest("hex");
              const pems = s => s.match(/-----BEGIN CERTIFICATE-----[\s\S]+?-----END CERTIFICATE-----/g) ?? [];
              const fail = m => { console.log(m); process.exit(1); };
              const C = "96bcec06264976f37460779acf28c5a7cfe8a3c0aae11a8ffcee05c0bddf08c6";
              const bundled = new Map(tls.rootCertificates.map(p => [fp(p), p]));
              const sys = new Map(pems(fs.readFileSync("/etc/ssl/certs/ca-certificates.crt", "utf8")).map(p => [fp(p), p]));
              if (bundled.size < 100 || sys.size < 100) fail(`bundled=${bundled.size} system=${sys.size}`);
              if (!bundled.has(C) || !sys.has(C)) fail(`C: compiled in=${bundled.has(C)} system=${sys.has(C)}, want true/true`);
              // subject -> DER hashes carrying it, across both lists
              const bySubject = new Map();
              for (const [h, p] of [...bundled, ...sys]) {
                const s = new X509Certificate(p).subject;
                bySubject.set(s, (bySubject.get(s) ?? new Set()).add(h));
              }
              const R = [...bundled.keys()].sort().find(h => {
                const x = new X509Certificate(bundled.get(h));
                return h !== C && x.publicKey.asymmetricKeyType === "rsa" && bySubject.get(x.subject).size === 1;
              });
              if (!R) fail("no compiled-in RSA root other than C with a unique subject");
              const sysx = [...sys].filter(([h]) => h !== R).map(([, p]) => p.trim());
              sysx.push(fs.readFileSync(process.argv[2], "utf8").trim());
              fs.writeFileSync("sysx.pem", sysx.join("\n") + "\n");
              fs.writeFileSync("R.pem", bundled.get(R).trim() + "\n");
              fs.writeFileSync("C.pem", bundled.get(C).trim() + "\n");
              // Sanity, read back from disk: R compiled in, not in sysx.pem; C in both.
              const back = new Set(pems(fs.readFileSync("sysx.pem", "utf8")).map(fp));
              if (!new Set(tls.rootCertificates.map(fp)).has(R) || back.has(R) || !back.has(C) || back.size !== sys.size - (sys.has(R) ? 1 : 0) + 1)
                fail(`sysx.pem: R=${R} in=${back.has(R)} C in=${back.has(C)} size=${back.size} (system ${sys.size})`);
              console.log(`R = ${R} ${new X509Certificate(bundled.get(R)).subject.replace(/\n/g, ", ")}`);
              JS
              clean bun roots.js sca.pem
              # bun's own view of the store under test: R absent, C and S present.
              cat > store.js <<'JS'
              const { X509Certificate, createHash } = require("node:crypto");
              const tls = require("node:tls");
              const fs = require("node:fs");
              const fp = p => createHash("sha256").update(new X509Certificate(p).raw).digest("hex");
              const sys = new Set(tls.getCACertificates("system").map(fp));
              const has = Object.fromEntries(process.argv.slice(2).map(f => [f, sys.has(fp(fs.readFileSync(f, "utf8")))]));
              if (sys.size < 100 || has["R.pem"] || !has["C.pem"] || !has["sca.pem"]) {
                console.log(`system store under test: size=${sys.size} ${JSON.stringify(has)}, want R absent, C and S present`);
                process.exit(1);
              }
              JS
              clean SSL_CERT_FILE="$d/sysx.pem" SSL_CERT_DIR="$d/empty" bun store.js R.pem C.pem sca.pem
              # R must also be absent by NAME (a same-subject root would be found).
              [ -z "$(ls -A empty)" ] || { echo "empty/ is not empty" >&2; exit 1; }
              openssl crl2pkcs7 -nocrl -certfile sysx.pem | openssl pkcs7 -print_certs -noout > sys.subjects
              if grep -qxF "$(openssl x509 -in R.pem -noout -subject)" sys.subjects; then
                echo "R's subject is in sysx.pem" >&2; exit 1
              fi
              # Control: the same match finds C's subject, so the guard can fire.
              grep -qxF "$(openssl x509 -in C.pem -noout -subject)" sys.subjects ||
                { echo "subject guard cannot match: C's subject not found in sysx.pem" >&2; exit 1; }

              n=0
              for p in R C; do
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

              # Prints e.g. "R=out C=in S=ok": ok = trusted, in/out = the forged
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
              sysx() { clean SSL_CERT_FILE="$d/sysx.pem" SSL_CERT_DIR="$d/empty" "$@"; }
              expect "R=out C=in S=ok" "sysx store, default" sysx bun check.js $real
              expect "R=in C=in S=ok" "sysx store, NODE_USE_SYSTEM_CA=0" sysx NODE_USE_SYSTEM_CA=0 bun check.js $real
              expect "R=in C=in S=ok" "sysx store, --use-bundled-ca" sysx bun --use-bundled-ca check.js $real
              expect "R=out C=in S=ok" "sysx store, --use-openssl-ca" sysx bun --use-openssl-ca check.js $real
              for v in 0 false no off; do
                expect "R=out C=in S=ok" "sysx store, --use-openssl-ca, NODE_USE_SYSTEM_CA=$v" \
                  sysx NODE_USE_SYSTEM_CA=$v bun --use-openssl-ca check.js $real
              done
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
        test_deps = [bash-bootstrap, coreutils],
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
