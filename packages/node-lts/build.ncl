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
let ca-certificates = import "../ca-certificates/build.ncl" in

let version = "24.22.1" in
{
  name = "node-lts",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://nodejs.org/dist/v%{version}/node-v%{version}.tar.gz",
      sha256 = "001773d9bd53fbd27a25efd42aa6a9693ebfe500998ca9bec635e9b6ee79bc91",
    } | Source,
    # 24.22.1 carries the CVE-2026-111943 fixes upstream (nodejs/node#66871 SPKI
    # blocklist, #66877 NSS 3.131.1 roots), so the backports are no longer carried.
    base,
    make,
    pkgconf,
    python,
    toolchain,
  ],
  runtime_deps = [
    # Note: lief is absent here (unlike packages/node/) because --shared-lief was not added
    # to Node.js configure until v25; the v24 LTS branch does not support it.
    coreutils, # npx/npm need /usr/bin/env
    openssl,
    c-ares,
    icu,
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
    # node trusts OpenSSL's default store, /etc/ssl (see build.sh), so the
    # system bundle must be present or every TLS connection fails.
    ca-certificates,
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
    # passes from 26.12.1 / 24.22.1 on (upstream nodejs/node#66877).
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
    # The default store is OpenSSL's (configure --openssl-use-def-ca-store; see
    # build.sh), so a CA removed from ca-certificates stops being trusted
    # (CVE-2026-111943). Offline: a local server presents a leaf from a
    # throwaway test CA (generated for this test only) that only SSL_CERT_FILE
    # names. node must trust it by default; stock node never reads
    # SSL_CERT_FILE, so this FAILS without the flag. `--use-bundled-ca`, on the
    # command line or in NODE_OPTIONS, must restore the compiled-in store (the
    # opt-out), and NODE_EXTRA_CA_CERTS must still add to either store.
    system_ca_store_default =
      {
        class = 'Standalone,
        test_deps = [base, ca-certificates],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              test -s /etc/ssl/cert.pem
              cd "$(mktemp -d)"
              cat > ca.pem <<'PEM'
              -----BEGIN CERTIFICATE-----
              MIIBtDCCAVmgAwIBAgIUFhL1HE8QlzdX9rxLMqgjzZM06Q4wCgYIKoZIzj0EAwIw
              JjEkMCIGA1UEAwwbbWluaW1hbCBzeXN0ZW0tY2EgdGVzdCByb290MCAXDTI2MTAy
              NzIwNTMxOVoYDzIxMjYxMDAzMjA1MzE5WjAmMSQwIgYDVQQDDBttaW5pbWFsIHN5
              c3RlbS1jYSB0ZXN0IHJvb3QwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAATaAlwQ
              KS9fPgBW5C+O7FH1/I6Zcqx9147goVmsjhQ5DYU75PkE42Yn88Upf0CjnhYDFNbc
              geNBE7eA3WO4p32Eo2MwYTAdBgNVHQ4EFgQUcfhuKz7RSGYiEVkMro8j7QLdIBcw
              HwYDVR0jBBgwFoAUcfhuKz7RSGYiEVkMro8j7QLdIBcwDwYDVR0TAQH/BAUwAwEB
              /zAOBgNVHQ8BAf8EBAMCAQYwCgYIKoZIzj0EAwIDSQAwRgIhAKlPKRkQ+p8uMZEl
              qVlK4XHDHRpJlYtilX6exV3Iy5wJAiEA80a+dVibtFHxU/nOxXYDeABFmB/o8j6f
              jUouX6GGu+Y=
              -----END CERTIFICATE-----
              PEM
              cat > leaf.pem <<'PEM'
              -----BEGIN CERTIFICATE-----
              MIIB0DCCAXegAwIBAgIUTKsxw15xmiIKgeXPoMw9gGDVMBAwCgYIKoZIzj0EAwIw
              JjEkMCIGA1UEAwwbbWluaW1hbCBzeXN0ZW0tY2EgdGVzdCByb290MCAXDTI2MTAy
              NzIwNTMxOVoYDzIxMjYxMDAzMjA1MzE5WjAUMRIwEAYDVQQDDAlsb2NhbGhvc3Qw
              WTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAASzn6+IiT2I2YKMGp/9kQx0iJ7s/8p/
              QFngX3riZETdPo0NY3viGbRG3IWUVxK4L3AnHelOSqOh850EeAwJ2xYCo4GSMIGP
              MBoGA1UdEQQTMBGCCWxvY2FsaG9zdIcEfwAAATAMBgNVHRMBAf8EAjAAMA4GA1Ud
              DwEB/wQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDATAdBgNVHQ4EFgQUsnsI/OSR
              ienMi5hFb5GEQa3qXaYwHwYDVR0jBBgwFoAUcfhuKz7RSGYiEVkMro8j7QLdIBcw
              CgYIKoZIzj0EAwIDRwAwRAIgLyftiw5mgD9+Si+BvKpTZQ+88O94b4/pHU+v8QSZ
              aVgCIFjojsmqMEc18V1NptXaS8I1cAtLpfiqq1O8cu13ASoC
              -----END CERTIFICATE-----
              PEM
              cat > leaf.key <<'PEM'
              -----BEGIN PRIVATE KEY-----
              MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg+h1vzS5mJhQDbYGJ
              B7KaNlcSUN29ISnfKkZXpAXc5q6hRANCAASzn6+IiT2I2YKMGp/9kQx0iJ7s/8p/
              QFngX3riZETdPo0NY3viGbRG3IWUVxK4L3AnHelOSqOh850EeAwJ2xYC
              -----END PRIVATE KEY-----
              PEM
              cat > probe.js <<'JSEOF'
              'use strict';
              const fs = require('fs');
              const tls = require('tls');
              const server = tls.createServer({ key: fs.readFileSync('leaf.key'), cert: fs.readFileSync('leaf.pem') },
                                              (s) => s.end());
              server.listen(0, '127.0.0.1', () => {
                const c = tls.connect({ port: server.address().port, host: '127.0.0.1', servername: 'localhost',
                                        rejectUnauthorized: false }, () => {
                  console.log(c.authorized ? 'authorized' : String(c.authorizationError));
                  c.destroy();
                  server.close();
                });
                c.on('error', (e) => { console.log('error ' + e.code); server.close(); });
              });
              JSEOF
              probe() { env -u NODE_OPTIONS -u NODE_EXTRA_CA_CERTS -u SSL_CERT_DIR SSL_CERT_FILE="$PWD/ca.pem" "$@"; }
              out=$(probe node probe.js)
              test "$out" = authorized || { echo "default store did not use SSL_CERT_FILE: $out" >&2; exit 1; }
              out=$(probe node --use-bundled-ca probe.js)
              case "$out" in UNABLE_TO_*) ;; *) echo "--use-bundled-ca: $out" >&2; exit 1 ;; esac
              out=$(probe env NODE_OPTIONS=--use-bundled-ca node probe.js)
              case "$out" in UNABLE_TO_*) ;; *) echo "NODE_OPTIONS=--use-bundled-ca: $out" >&2; exit 1 ;; esac
              out=$(probe env NODE_EXTRA_CA_CERTS="$PWD/ca.pem" node --use-bundled-ca probe.js)
              test "$out" = authorized || { echo "NODE_EXTRA_CA_CERTS with --use-bundled-ca: $out" >&2; exit 1; }
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
