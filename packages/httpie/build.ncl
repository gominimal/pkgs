let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let uv = import "../uv/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in

# HTTPie — the human-friendly HTTP client the agentbox image installs via dnf.
#
# Packaged the same way as diffoscope: `pip3 install` into $OUTPUT_DIR and ship
# the resulting site-packages, rather than packaging the dependency closure by
# hand. httpie pulls in requests, rich, pygments, multidict, defusedxml,
# requests-toolbelt and their transitive deps — 12 distributions — and every one
# of them is pure Python with no reason to exist as a separate pkgs entry.
#
# (We do also ship `xh`, a Rust HTTPie-alike. It is a good substitute for the
# common cases but not a drop-in: different flag surface, no sessions, no
# plugins. Both can coexist.)
#
# The dependency closure is pinned in requirements.lock (version + sha256 for
# every distribution), which build.sh installs with --require-hashes. It used to
# be resolved from PyPI at build time with no pins, so the shipped tree, and
# certifi's CA bundle in particular, was whatever PyPI served that day. The lock
# also holds certifi at or above 2026.10.19, the first release without emSign ECC
# Root CA - G3 (CVE-2026-111943).
#
# `needs` is still set: pip fetches the locked wheels, and httpie's build
# backend, from PyPI during the build.
let version = "3.2.4" in

{
  name = "httpie",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "requirements.lock" } | Local,
    {
      url = "https://github.com/httpie/httpie/archive/refs/tags/%{version}.tar.gz",
      sha256 = "b185cd8d81325f97c773582e50f1c5e047c2d8575b53d676469c9daf2a52f341",
      extract = true,
      strip_prefix = "cli-%{version}",
    } | Source,
    base,
    toolchain,
    uv,
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  runtime_deps = [
    python,
    # certifi.where() returns the system bundle when it exists (build.sh), so
    # ship it rather than fall back to certifi's own.
    ca-certificates,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/http*" } | OutputBin,
    # allow_executable, because not every dependency is pure Python:
    # charset_normalizer and multidict ship compiled C extensions
    # (md.cpython-314-aarch64-linux-gnu.so and friends) and the output-types
    # check otherwise rejects a data output for matching a binary/library file.
    # This is numpy's pattern; splitting the .so files into a separate
    # OutputLib does NOT work, because the data glob still matches them too.
    site_packages = { glob = "usr/lib/python*/site-packages/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "httpie",
        repo = "cli",
      },
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "/bin/http --version | grep -q 3.2.4"],
          # Exercise an actual import path, not just --version: httpie's
          # entrypoint pulls in requests/rich/pygments, so a missing dependency
          # surfaces here rather than at first real use.
          ["/bin/bash", "-c", "/bin/http --help >/dev/null"],
        ],
      } | Test,

    # CVE-2026-111943 regression: certifi's own bundle (requests' fallback when
    # the system store is missing) must not trust emSign ECC Root CA - G3
    # (distrusted by Mozilla, bug 2083449). Checked by SHA-256 fingerprint,
    # offline. FAILS with certifi <= 2026.07.22.
    certifi_distrusts_emsign_ecc_g3 =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              cat > poc.py <<'PYEOF'
              import hashlib, re, ssl, sys
              import certifi.core

              G3 = '86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b'
              pem = open(certifi.core._minimal_certifi_where()).read()
              fps = {hashlib.sha256(ssl.PEM_cert_to_DER_cert(c)).hexdigest()
                     for c in re.findall(r'-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----',
                                         pem, re.S)}
              failures = []
              if len(fps) < 100:
                  failures.append('certifi bundle has only %d roots' % len(fps))
              if G3 in fps:
                  failures.append('certifi trusts emSign ECC Root CA - G3')
              for f in failures:
                  print('FAIL: ' + f, file=sys.stderr)
              sys.exit(1 if failures else 0)
              PYEOF
              python3 poc.py
            "%
          ],
        ],
      } | Test,
    # requests' default bundle is the system CA store (build.sh), so a CA
    # removed from ca-certificates stops being trusted (CVE-2026-111943).
    # FAILS on stock httpie, where where() is certifi's cacert.pem. Offline, a
    # local HTTPS server with a leaf from a throwaway test CA (generated for
    # this test only, in no store) must be rejected by default and accepted
    # with REQUESTS_CA_BUNDLE or --verify naming that CA: the user override.
    system_ca_default =
      {
        class = 'Standalone,
        test_deps = [base, ca-certificates],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              test -s /etc/ssl/certs/ca-certificates.crt
              python3 - <<'PYEOF'
              import certifi, requests.certs, requests.utils
              system = "/etc/ssl/certs/ca-certificates.crt"
              for name, got in [("certifi.where()", certifi.where()),
                                ("requests.certs.where()", requests.certs.where()),
                                ("requests.utils.DEFAULT_CA_BUNDLE_PATH", requests.utils.DEFAULT_CA_BUNDLE_PATH)]:
                  assert got == system, f"{name} = {got}, not the system bundle"
              PYEOF
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
              cat > server.py <<'PYEOF'
              import http.server, os, ssl
              srv = http.server.HTTPServer(("127.0.0.1", 0), http.server.SimpleHTTPRequestHandler)
              ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
              ctx.load_cert_chain("leaf.pem", "leaf.key")
              srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
              with open("port.tmp", "w") as f:
                  f.write(str(srv.server_address[1]))
              os.rename("port.tmp", "port")
              srv.serve_forever()
              PYEOF
              python3 server.py > /dev/null 2>&1 &
              server=$!
              trap 'kill "$server"' EXIT
              for _ in $(seq 100); do [ -s port ] && break; sleep 0.1; done
              url="https://localhost:$(cat port)/"
              unset HTTPS_PROXY https_proxy HTTP_PROXY http_proxy ALL_PROXY all_proxy REQUESTS_CA_BUNDLE CURL_CA_BUNDLE
              if http --ignore-stdin --check-status --timeout 10 GET "$url" > out 2>&1; then
                echo "an unknown CA was trusted by default" >&2; exit 1
              fi
              grep -qi 'certificate verify failed' out || { cat out >&2; exit 1; }
              REQUESTS_CA_BUNDLE="$PWD/ca.pem" http --ignore-stdin --check-status --timeout 10 GET "$url" > /dev/null
              http --ignore-stdin --check-status --timeout 10 --verify="$PWD/ca.pem" GET "$url" > /dev/null
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
