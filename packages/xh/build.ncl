# Imported from Wolfi `xh` by `pkgmgr import-wolfi` (rust build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let version = "0.26.2" in
{
  name = "xh",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/ducaale/xh/v%{version}.tar.gz",
      sha256 = "61a88a5b3beac225b75a11d6ed32659af78db7ff29c825def0ab7f4a2906cbd7",
      extract = true,
      strip_prefix = "xh-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
    make,
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,
  cmd = "./build.sh",
  outputs = {
    xh = { glob = "usr/bin/xh" } | OutputBin,
  },
  runtime_deps = [glibc, subsetOf gcc ["libgcc"]],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "ducaale", repo = "xh" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Smoke test ported from the Wolfi recipe's test block.
          ["/bin/bash", "-c", "xh --version"],
          ["/bin/bash", "-c", "xh --help"],
          ["/bin/bash", "-c", "set -euo pipefail\noutput=$(xh --offline GET https://example.com)\necho \"$output\" | grep -F \"GET / HTTP\""],
          ["/bin/bash", "-c", "set -euo pipefail\noutput=$(echo '{\"key\":\"value\"}' | xh --offline POST https://example.com Content-Type:application/json)\necho \"$output\" | grep -F \"key\""],
          ["/bin/bash", "-c", "set -euo pipefail\noutput=$(xh --offline GET https://example.com X-Custom:test)\necho \"$output\" | grep -F \"X-Custom: test\""],
        ],
      } | Test,
  },
} | BuildSpec
