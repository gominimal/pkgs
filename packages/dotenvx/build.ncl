let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let node-lts = import "../node-lts/build.ncl" in

# Runs on node-lts from upstream's source release, NOT the prebuilt release
# binary. CVE-2026-111943 (eMudhra intermediate key compromise): the release
# binary is a yao-pkg executable around Node v20.20.0, whose compiled-in root
# store still holds emSign ECC Root CA - G3, and nothing at runtime can change
# that. Checked with the TLS trust harness (gominimal/pkgs#976) against 2.38.2:
#   * it connects to the eMudhra test hosts;
#   * yao-pkg's node ignores NODE_OPTIONS (process.execArgv stays empty), so
#     `--use-openssl-ca` cannot be injected;
#   * Node 20 has no NODE_USE_SYSTEM_CA, and on newer node that flag only ADDS
#     the system store to the bundled one, so it would not remove the root.
# It matters here: dotenvx talks HTTPS to its key service (`dotenvx armor`,
# `dotenvx curl`, the background event worker), carrying bearer tokens and keys.
# node-lts 24.22.1 drops the emSign roots and blocks the 8 compromised keys
# (nodejs/node#66871, #66877; see node-lts's own tests).
#
# The source tarball also retires the old caveat that the binary could not be
# rebuilt: this is upstream's npm distribution (`npm i -g @dotenvx/dotenvx`),
# which upstream supports alongside the binary (`process.pkg` branches).
# Behaviour difference: `dotenvx update` prints the npm command instead of
# piping https://dotenvx.sh into sh.
let version = "2.38.2" in
{
  name = "dotenvx",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/dotenvx/dotenvx/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "521cee25b8aa23e427220eed8b255e4c05ce5e71bffcf55598086a3fd0252f02",
      extract = true,
      strip_prefix = "dotenvx-%{version}",
    } | Source,
    base,
    node-lts,
  ],
  runtime_deps = [
    coreutils,
    subsetOf node-lts ["node"],
  ],
  # `npm ci` fetches the lockfile's tarballs (exact versions, sha512-checked).
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    dotenvx = { glob = "usr/bin/dotenvx" } | OutputBin,
    libexec = { glob = "usr/libexec/dotenvx/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "dotenvx",
        repo = "dotenvx",
      },
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "/bin/dotenvx --version | grep -qx '%{version}'"],
        ],
      } | Test,
    run =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo 'HELLO=World' > .env"],
          ["/bin/bash", "-c", "/bin/dotenvx run -- /bin/bash -c 'echo $HELLO' | grep -q '^World$'"],
        ],
      } | Test,
    # CVE-2026-111943: dotenvx must run on the node runtime dep, never again on
    # an embedded one, and that runtime's default store must not hold the
    # emSign roots NSS 3.131.1 removed (fingerprints as in node-lts's
    # emsign_roots_removed test).
    trust_store_without_emsign =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "test \"$(head -c 19 /bin/dotenvx)\" = '#!/usr/bin/env node'"],
          [
            "/bin/bash",
            "-c",
            m%"
              cat > roots.js <<'JSEOF'
              const tls = require('tls');
              const { X509Certificate } = require('crypto');
              const removed = {
                '86:A1:EC:BA:08:9C:4A:8D:3B:BE:27:34:C6:12:BA:34:1D:81:3E:04:3C:F9:E8:A8:62:CD:5C:57:A3:6B:BE:6B': 'emSign ECC Root CA - G3',
                '12:56:09:AA:30:1D:A0:A2:49:B9:7A:82:39:CB:6A:34:21:6F:44:DC:AC:9F:39:54:B1:42:92:F2:E8:C8:60:8F': 'emSign Root CA - C1',
                'BC:4D:80:9B:15:18:9D:78:DB:3E:1D:8C:F4:F9:72:6A:79:5D:A1:64:3C:A5:F1:35:8E:1D:DB:0E:DC:0D:7E:B3': 'emSign ECC Root CA - C3',
              };
              const store = typeof tls.getCACertificates === 'function' ? tls.getCACertificates('default') : tls.rootCertificates;
              const fps = store.map((p) => new X509Certificate(p).fingerprint256);
              if (fps.length < 100) { console.error('only ' + fps.length + ' default CAs'); process.exit(2); }
              const hits = fps.filter((f) => f in removed).map((f) => removed[f]);
              if (hits.length) { console.error('still trusted: ' + hits.join(', ')); process.exit(1); }
              console.log('ok: ' + fps.length + ' default CAs, none of the 3 removed emSign roots');
              JSEOF
              node roots.js
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
