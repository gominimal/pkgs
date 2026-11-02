let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let node-lts = import "../node-lts/build.ncl" in

# TODO: build rather than fetch
#
# Runs upstream's npm distribution on node-lts, NOT the release binary.
# CVE-2026-111943 (eMudhra intermediate key compromise): the release binary is a
# `bun build --compile` executable around Bun 1.4.2, whose compiled-in root store
# still holds emSign ECC Root CA - G3. Checked with the TLS trust harness
# (gominimal/pkgs#976) against 1.23.0: it connects to the eMudhra test hosts, and
# no runtime switch helps: with NODE_USE_SYSTEM_CA=1, BUN_OPTIONS=--use-system-ca,
# NODE_OPTIONS=--use-openssl-ca, or either flag on argv, it still connects (the
# bundled roots stay trusted). Bun fixed its store in 1.4.4 (oven-sh/bun#46300,
# NSS 3.131.1 + the 8 blocked keys), but varlock has not released a binary built
# with it. The store matters: varlock downloads `@plugin` code from
# registry.npmjs.org over HTTPS and runs it, and sends telemetry.
#
# The npm package is upstream's supported install (`npm i varlock`, engines
# node >=22.3): a dependency-free bundled build plus one optional per-platform
# package holding the native `varlock-local-encrypt` helper (byte-identical to the
# one in the release tarball, checked on arm64; statically linked on both arches,
# so the glibc runtime dep the bun binary needed is gone). node-lts 24.22.1 drops the
# emSign roots and blocks the 8 compromised keys (nodejs/node#66871, #66877).
# Go back to the binary only once a release is built with Bun >= 1.4.4, and
# check it with the harness.
let version = "1.24.0" in
{
  name = "varlock",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://registry.npmjs.org/varlock/-/varlock-%{version}.tgz",
      sha256 = "c90d73765bcb81e6d246b26ddc88d4d15f7a37db287a83eb493b02e2393a09da",
    } | Source,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://registry.npmjs.org/@varlock/native-helper-linux-x64/-/native-helper-linux-x64-%{version}.tgz",
          sha256 = "326635b64c2fd33b2ec893519a36b623f78c925dc3393d89a89a5d511e407187",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://registry.npmjs.org/@varlock/native-helper-linux-arm64/-/native-helper-linux-arm64-%{version}.tgz",
          sha256 = "fc02283e4d6816767653300134c35396f4615d858ecb03b352bb87ce53cf2ff3",
        } | Source,
    } target,
    base,
  ],
  runtime_deps = [
    coreutils,
    subsetOf node-lts ["node"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    varlock = { glob = "usr/bin/varlock" } | OutputBin,
    # The bundled native helper varlock invokes (by name) for local-encrypt.
    varlock-local-encrypt = { glob = "usr/bin/varlock-local-encrypt" } | OutputBin,
    libexec = { glob = "usr/libexec/varlock/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "dmno-dev",
        repo = "varlock",
      },
    } | Attrs,

  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "varlock --version | grep -q '%{version}'"],
          ["/bin/bash", "-c", "varlock --help"],
          ["/bin/bash", "-c", "test -x \"$(readlink -f /usr/bin/varlock-local-encrypt)\""],
        ],
      }
        | Test,
    # CVE-2026-111943: varlock must run on the node runtime dep, never again on
    # an embedded runtime, and that runtime's default store must not hold the
    # emSign roots NSS 3.131.1 removed (fingerprints as in node-lts's
    # emsign_roots_removed test).
    trust_store_without_emsign =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "test \"$(head -c 19 /usr/bin/varlock)\" = '#!/usr/bin/env node'"],
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
