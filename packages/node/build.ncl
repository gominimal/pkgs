let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let make = import "../make/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let python = import "../python/build.ncl" in
let base = import "../base/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let c-ares = import "../c-ares/build.ncl" in
let icu = import "../icu/build.ncl" in
let lief = import "../lief/build.ncl" in
let patch = import "../patch/build.ncl" in
let libuv = import "../libuv/build.ncl" in
let nghttp2 = import "../nghttp2/build.ncl" in
let nghttp3 = import "../nghttp3/build.ncl" in
let ngtcp2 = import "../ngtcp2/build.ncl" in
let sqlite = import "../sqlite/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let zstd = import "../zstd/build.ncl" in
let gtest = import "../gtest/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "26.10.0" in
{
  name = "node",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/node-%{version}.tar.gz",
      sha256 = "dadc307a5353706728704a90316800df6834cb4928d0a227451295166a3b3d27",
    } | Source,
    # Adapts the Mach-O SEA injection to the LIEF 1.x Section API — see
    # the patch header. Build-time only: it rewrites the source tree.
    { file = "lief-1.x-macho-section-ctor.patch" } | Local,
    # CVE-2026-111943 (eMudhra key compromise): backports of nodejs/node#66871
    # (SPKI blocklist in TLS chain verification) and nodejs/node#66877 (drop the
    # emSign roots removed in NSS 3.131.1), both merged to main 2026-10-20 and
    # unreleased. Build-time only; see the patch headers. Drop both on the first
    # release whose changelog lists them.
    { file = "cve-2026-111943-tls-spki-blocklist.patch" } | Local,
    { file = "cve-2026-111943-drop-emsign-roots.patch" } | Local,
    base,
    make,
    pkgconf,
    patch,
    python,
    toolchain,
  ],
  runtime_deps = [
    coreutils, # npx/npm need /usr/bin/env
    openssl,
    c-ares,
    icu,
    lief,
    libuv,
    zlib,
    sqlite,
    nghttp2,
    nghttp3,
    ngtcp2,
    zstd,
    gtest,
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    node = { glob = "usr/bin/node" } | OutputBin,
    npx = { glob = "usr/bin/npx" } | OutputBin,
    npm = { glob = "usr/bin/npm" } | OutputBin,
    node_modules = { glob = "usr/lib/node_modules/**" } | OutputData,

    includes = { glob = "usr/include/**" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      env_state_wiring = {
        env_var = "NPM_CONFIG_CACHE",
        prefix = "npm-cache",
      },
      source_provenance = {
        category = 'GithubRepo,
        owner = "nodejs",
        repo = "node",
      },
      build_cost_multiple = 5,
    } | Attrs,

  tests = {
    eval =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo 'console.log(\"Hello Node\")' > script.js"],
          ["/bin/bash", "-c", "node script.js | grep -q '^Hello Node$'"],
          ["/bin/bash", "-c", "echo 'console.log(2 + 2)' > math.js"],
          ["/bin/bash", "-c", "node math.js | grep -q '^4$'"],
        ],
      } | Test,
    inline_eval =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "node -e 'console.log(10 * 5)' | grep -q '^50$'"],
        ],
      } | Test,
    npm_global_prefix =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # The builtin npmrc must redirect npm's global prefix away from the
          # read-only /usr store (gominimal/inbox#559).
          ["/bin/bash", "-c", "npm config get prefix | grep -q '/.local$'"],
        ],
      } | Test,

    # CVE-2026-111943: the emSign roots NSS 3.131.1 removed must be gone from
    # the BUNDLED store (what `tls` trusts by default). FAILS on stock node
    # (checked against node 26.9.0: all three are present) and
    # passes only with cve-2026-111943-drop-emsign-roots.patch.
    emsign_roots_removed =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
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
              const fps = tls.rootCertificates.map((p) => new X509Certificate(p).fingerprint256);
              // Guard against a vacuous pass: the bundled store must still be populated.
              if (fps.length < 100) { console.error('only ' + fps.length + ' bundled roots'); process.exit(2); }
              const hits = fps.filter((f) => f in removed).map((f) => removed[f]);
              if (hits.length) { console.error('still bundled: ' + hits.join(', ')); process.exit(1); }
              console.log('ok: ' + fps.length + ' bundled roots, none of the 3 removed emSign roots');
              JSEOF
              node roots.js
            "%
          ],
        ],
      } | Test,

    # CVE-2026-111943: the compiled-in SPKI blocklist (nodejs/node#66871),
    # exercised with a REAL compromised eMudhra intermediate and no network.
    # A local server presents a throwaway self-signed leaf plus one extra cert.
    # The leaf is untrusted, so verification fails and the patched callback
    # scans every peer-sent cert: with the compromised intermediate attached,
    # the error must become CERT_REVOKED; with an unrelated cert attached
    # (control) it must not. Stock node reports DEPTH_ZERO_SELF_SIGNED_CERT for
    # both (checked against node 26.9.0), so this fails without the patch. The
    # intermediate's private key is not needed or used.
    spki_blocklist_rejects_emudhra_intermediate =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              cat > blocklist.js <<'JSEOF'
              'use strict';
              const tls = require('tls');
              // Throwaway self-signed localhost key/cert, generated for this test only.
              const leafKey = `-----BEGIN PRIVATE KEY-----
              MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgBntishQTKnOQ5BYq
              YMl6DN2832k3mPEuBBivBy/pZhuhRANCAARH7UBOAcealWpyFbYPHWsN7KwkGjbh
              XaFy2MaYD4iRky5fXTP4oLh30Y4WGuqnidQo8NH3rLPA/eHByaZK7nSo
              -----END PRIVATE KEY-----`;
              const leafCert = `-----BEGIN CERTIFICATE-----
              MIIBljCCATugAwIBAgIUDse2MObwU7yD+AVlIg+O5FY8oRowCgYIKoZIzj0EAwIw
              FDESMBAGA1UEAwwJbG9jYWxob3N0MCAXDTI2MTAyMDIyMzQxNVoYDzIxMjYwOTI2
              MjIzNDE1WjAUMRIwEAYDVQQDDAlsb2NhbGhvc3QwWTATBgcqhkjOPQIBBggqhkjO
              PQMBBwNCAARH7UBOAcealWpyFbYPHWsN7KwkGjbhXaFy2MaYD4iRky5fXTP4oLh3
              0Y4WGuqnidQo8NH3rLPA/eHByaZK7nSoo2kwZzAdBgNVHQ4EFgQUJW3YJUswqwV2
              eQeQjD699UlVE94wHwYDVR0jBBgwFoAUJW3YJUswqwV2eQeQjD699UlVE94wDwYD
              VR0TAQH/BAUwAwEB/zAUBgNVHREEDTALgglsb2NhbGhvc3QwCgYIKoZIzj0EAwID
              SQAwRgIhAN5h2+ujZZh9fAX3pbs36JbQm12AgxmBq5OdAxWrz0MvAiEArtKXS5Ev
              uVh2ceJcjY/zb7ExiHzJlcxeUO5NAB7xCTw=
              -----END CERTIFICATE-----`;
              // REAL compromised intermediate: C=US, O=eMudhra Inc, CN=EM OV TLS CA - G3C
              // (sha256 CB6E15165AC802E9B3F993F16C25D41F4E81C21EBDE71AE1B012AC00BF9C7C3F,
              // SPKI sha256 63ecefee...9cf8, 4th entry of kBlockedSPKIs). Public cert only.
              const blocked = `-----BEGIN CERTIFICATE-----
              MIIDaDCCAu6gAwIBAgIPKWkmwiejoVJjkrGUgqUEMAoGCCqGSM49BAMDMFYxCzAJ
              BgNVBAYTAklOMSUwIwYDVQQKDBxlTXVkaHJhIFRlY2hub2xvZ2llcyBMaW1pdGVk
              MSAwHgYDVQQDDBdlbVNpZ24gUm9vdCBUTFMgQ0EgLSBHMzAeFw0yNTA0MzAxNTM3
              NDFaFw00MDA0MjgxODMwMDBaMEAxCzAJBgNVBAYTAlVTMRQwEgYDVQQKDAtlTXVk
              aHJhIEluYzEbMBkGA1UEAwwSRU0gT1YgVExTIENBIC0gRzNDMHYwEAYHKoZIzj0C
              AQYFK4EEACIDYgAEE4JRzVKskpjByKrZdzId65fnCb0LTKCspV3IrVHc/J0ViaFZ
              fjpRIOHv1jHGPhg1ysrimGmmLhYx6KKBgatWYW3EXZGKvAnzqw5jz3kqpNztc4e+
              N7ulaVSfHAKycO1no4IBljCCAZIwHwYDVR0jBBgwFoAU4TqrIXzx401UrtRyt/2L
              WUIgkFQwHQYDVR0OBBYEFDTq6gzryQra+dDF4u2beMmHnhtsMB0GA1UdJQQWMBQG
              CCsGAQUFBwMBBggrBgEFBQcDAjBdBgNVHSAEVjBUMDkGCysGAQQBg44hAQABMCow
              KAYIKwYBBQUHAgEWHGh0dHA6Ly9yZXBvc2l0b3J5LmVtc2lnbi5jb20wDQYLKwYB
              BAGDjiEBAm4wCAYGZ4EMAQICMHUGCCsGAQUFBwEBBGkwZzAkBggrBgEFBQcwAYYY
              aHR0cDovL29jc3AtYy5lbXNpZ24uY29tMD8GCCsGAQUFBzAChjNodHRwOi8vcmVw
              b3NpdG9yeS5lbXNpZ24uY29tL2NlcnRzL0VNT1ZUTFNDQUczQy5wN2MwNwYDVR0f
              BDAwLjAsoCqgKIYmaHR0cDovL2NybC5lbXNpZ24uY29tLz9yb290dGxzY2FnMy5j
              cmwwDgYDVR0PAQH/BAQDAgEGMBIGA1UdEwEB/wQIMAYBAf8CAQAwCgYIKoZIzj0E
              AwMDaAAwZQIxAMSZt2xsPeumRdeSMSQ3CbzIZeQ/q7GDCWfeE1Pq+mhgA6gRM44c
              NVF3xJ+wsxJk+wIwFJbaDMokD8Ei6eNOiA8yUMYvfzQyngmrhZQMdPCK1SewrR79
              4rSb9vGqxZzelQth
              -----END CERTIFICATE-----`;
              // Unrelated self-signed cert (public part only) for the control probe.
              const unrelated = `-----BEGIN CERTIFICATE-----
              MIIBfzCCASWgAwIBAgIUMlp45Gz2s2WZcjmuScXJvcNL9wIwCgYIKoZIzj0EAwIw
              FDESMBAGA1UEAwwJdW5yZWxhdGVkMCAXDTI2MTAyMDIyMzQxNVoYDzIxMjYwOTI2
              MjIzNDE1WjAUMRIwEAYDVQQDDAl1bnJlbGF0ZWQwWTATBgcqhkjOPQIBBggqhkjO
              PQMBBwNCAAQOzAYjCJw8zYxjnTgcx5mXxHW1AUQjRwPDgYzTXCC5hvEc/8/eWnyx
              xTBtol+ZJEfe5E1/E18HPhsQzio03buco1MwUTAdBgNVHQ4EFgQUUKKd1zdu9Swr
              C/u/vFyyF3KcX24wHwYDVR0jBBgwFoAUUKKd1zdu9SwrC/u/vFyyF3KcX24wDwYD
              VR0TAQH/BAUwAwEB/zAKBggqhkjOPQQDAgNIADBFAiEAhRYCZ2DlkB58K8S2So8z
              o17WxT6iVqn1rkr/6mOHNlcCIDzD/YRYVMZFDSWv0mpgj8ZC1jkR+tq5tfc1dWaq
              6zcr
              -----END CERTIFICATE-----`;
              function probe(extra) {
                return new Promise((resolve, reject) => {
                  const server = tls.createServer({ key: leafKey, cert: leafCert + '\n' + extra },
                                                  (s) => s.end());
                  server.listen(0, '127.0.0.1', () => {
                    const c = tls.connect({ port: server.address().port, host: '127.0.0.1',
                                            rejectUnauthorized: false, checkServerIdentity() {} },
                                          () => {
                                            const e = c.authorizationError;
                                            c.destroy();
                                            server.close();
                                            resolve(String(e));
                                          });
                    c.on('error', (e) => { server.close(); reject(e); });
                  });
                });
              }
              (async () => {
                const control = await probe(unrelated);
                const hit = await probe(blocked);
                console.log('control=' + control + ' blocked=' + hit);
                if (control === 'CERT_REVOKED' || hit !== 'CERT_REVOKED') process.exit(1);
              })().catch((e) => { console.error(e); process.exit(2); });
              JSEOF
              node blocklist.js
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
