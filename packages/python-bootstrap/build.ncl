let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in
let make = import "../make/build.ncl" in
let patch = import "../patch/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in

# The CPython that glibc's build runs (configure and scripts/*.py), and nothing
# else. It keeps the full `python` package out of gcc's build graph
# (gcc -> glibc -> python), so python and openssl can take libgcc_s from
# gcc-runtime: glibc dlopens libgcc_s.so.1 to unwind on pthread_exit and aborts
# without it, and gcc_runtime_guard rule 4 forbids gcc-runtime in gcc's graph.
#
# It installs under its own prefix, /usr/lib/python-bootstrap, so it never ships
# a path that python ships. It is static (no libpython.so), builds no module
# that needs an optional library, has no pip, and its only runtime dependency is
# glibc. Keep version and source equal to packages/python: they are the same
# CPython release, and the same VEX statements cover both.
let version = "3.14.10" in
{
  name = "python-bootstrap",
  build_deps = [
    { file = "build.sh" } | Local,
    # The same gh-143923 backport python carries (CVE-2025-15367). This package
    # shares python's identity (pkg:github/python/cpython), so the not_affected
    # VEX statement filed for python covers it too, and has to stay true here:
    # drop the patch only together with python's, when a 3.14.x release lists
    # gh-143923.
    { file = "0003-gh-143923-poplib-reject-control-characters.patch" } | Local,
    {
      url = "gs://minimal-staging-archives/Python-%{version}.tar.xz",
      sha256 = "de414a57119abef52784d8993e341d53aed635fc2b05c2607d9f98a2c5b72032"
    } | Source,
    base,
    make,
    patch,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    bin = { glob = "usr/lib/python-bootstrap/bin/*" } | OutputBin,
    stdlib = { glob = "usr/lib/python-bootstrap/lib/python*/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Python-2.0.1",
      source_provenance = {
        category = 'GithubRepo,
        owner = "python",
        repo = "cpython",
      },
    } | Attrs,

  tests = {
    # The interpreter runs, is this release, and imports what glibc's build
    # scripts use (scripts/*.py: argparse, re, subprocess, tempfile, ...).
    runs_glibc_build_modules =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              py=/usr/lib/python-bootstrap/bin/python3
              "$py" --version | grep -qx 'Python %{version}'
              "$py" -c 'import argparse, collections, itertools, os, pathlib, re, string, subprocess, sys, tempfile'
            "%
          ],
        ],
      } | Test,
    # The gh-143923 backport is in: poplib refuses a command with CR/LF.
    poplib_rejects_control_characters =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              cat > poc.py <<'PYEOF'
              import poplib, sys

              class Fake(poplib.POP3):
                  def __init__(self):
                      self.encoding = 'UTF-8'
                      self._debugging = 0
                      self.sent = []
                  def _putline(self, line):
                      self.sent.append(line)

              failures = []
              f = Fake()
              f._putcmd('USER alice')
              if f.sent != [b'USER alice']:
                  failures.append('a normal command was not sent: %r' % (f.sent,))
              for bad in ('USER a\r\nDELE 1', 'USER a\nQUIT', 'NOOP\x00', 'USER a\x7f'):
                  try:
                      f._putcmd(bad)
                  except ValueError:
                      continue
                  failures.append('control characters were sent: %r' % (bad,))

              for m in failures:
                  print('FAIL: ' + m, file=sys.stderr)
              sys.exit(1 if failures else 0)
              PYEOF
              /usr/lib/python-bootstrap/bin/python3 poc.py
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
