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
    # The system CA store is what bun trusts by default (system-ca-store-
    # default.patch), so a CA removed from ca-certificates stops being trusted
    # (CVE-2026-111943). Offline, against a REAL local TLS server: a throwaway
    # CA signs a 127.0.0.1 leaf, `openssl s_server` serves it, and SSL_CERT_FILE
    # names that CA as the whole system store.
    #   - default: trusted (stock bun only uses its compiled-in roots, so it
    #     rejects this CA: the test FAILS without the patch);
    #   - NODE_USE_SYSTEM_CA=0 and --use-bundled-ca (the opt-outs): rejected.
    # Checked through tls.connect; fetch's answers are printed as a diagnostic.
    # (The removal direction, a compiled-in root missing from the system store
    # is untrusted, needs a real root's key, so it rests on the patch's grep
    # guards in build.sh. An earlier keyless fake-server harness gave
    # unusable answers on 1.3.14 in the sandbox.)
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
              d=$(mktemp -d)
              cd "$d"
              openssl req -x509 -newkey rsa:2048 -nodes -days 2 -subj "/CN=minimal test CA" \
                -keyout ca.key -out ca.pem 2>/dev/null
              openssl req -newkey rsa:2048 -nodes -subj "/CN=127.0.0.1" -keyout leaf.key -out leaf.csr 2>/dev/null
              printf 'subjectAltName=IP:127.0.0.1\n' > ext.cnf
              openssl x509 -req -in leaf.csr -CA ca.pem -CAkey ca.key -CAcreateserial -days 2 \
                -extfile ext.cnf -out leaf.pem 2>/dev/null
              port=$(( 20000 + RANDOM % 20000 ))
              openssl s_server -accept "127.0.0.1:$port" -cert leaf.pem -key leaf.key -www -quiet >/dev/null 2>&1 &
              srv=$!
              trap 'kill $srv 2>/dev/null || true' EXIT
              for _ in $(seq 100); do (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null && break; sleep 0.1; done
              mkdir -p empty
              cat > check.js <<JS
              const port = $port;
              const viaTls = () => new Promise(r => require("node:tls")
                .connect({ host: "127.0.0.1", port })
                .on("secureConnect", function () { this.destroy(); r("ok"); })
                .on("error", e => r(String(e.code))));
              const viaFetch = () => fetch("https://127.0.0.1:" + port + "/").then(() => "ok", e => String(e.code));
              (async () => { console.log(await viaTls() + " fetch=" + await viaFetch()); process.exit(0); })();
              setTimeout(() => { console.log("timeout"); process.exit(3); }, 20000).unref();
              JS
              run() {
                flag=$1; shift
                env -u NODE_USE_SYSTEM_CA -u NODE_EXTRA_CA_CERTS -u HTTPS_PROXY -u https_proxy -u HTTP_PROXY -u http_proxy -u ALL_PROXY -u all_proxy \
                  SSL_CERT_FILE="$d/ca.pem" SSL_CERT_DIR="$d/empty" "$@" bun $flag check.js || true
              }
              got=$(run ""); echo "default: $got"
              case "$got" in ok*) ;; *) echo "default does not trust the system store: $got" >&2; exit 1 ;; esac
              got=$(run "" NODE_USE_SYSTEM_CA=0); echo "NODE_USE_SYSTEM_CA=0: $got"
              case "$got" in ok*|timeout*|"") echo "NODE_USE_SYSTEM_CA=0 still trusts the system store: $got" >&2; exit 1 ;; esac
              got=$(run --use-bundled-ca); echo "--use-bundled-ca: $got"
              case "$got" in ok*|timeout*|"") echo "--use-bundled-ca still trusts the system store: $got" >&2; exit 1 ;; esac
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
