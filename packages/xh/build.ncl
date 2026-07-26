# Imported from Wolfi `xh` by `pkgmgr import-wolfi` (rust build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let version = "0.26.1" in
{
  name = "xh",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/ducaale/xh/v%{version}.tar.gz",
      sha256 = "6c4822374d3b9bacfc50719ffb5653a32fd84344e50fd88b499ed8fc9e52198b",
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
