let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let uv = import "../uv/build.ncl" in

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

    # CVE-2026-111943 regression: the CA bundle requests verifies against must
    # not trust emSign ECC Root CA - G3 (distrusted by Mozilla, bug 2083449).
    # Checked by SHA-256 fingerprint, offline. FAILS with certifi <= 2026.07.22.
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
              import requests.certs

              G3 = '86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b'
              pem = open(requests.certs.where()).read()
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
  },
} | BuildSpec
