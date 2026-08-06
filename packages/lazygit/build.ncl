# Imported from Wolfi `lazygit` by `pkgmgr import-wolfi` (go build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "0.64.0" in
{
  name = "lazygit",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/jesseduffield/lazygit/v%{version}.tar.gz",
      sha256 = "2d41928fd3c6355022f0876ac5b8abc89ece40bf3ab9b8353f254d420d938201",
      extract = true,
      strip_prefix = "lazygit-%{version}",
    } | Source,
    base,
    go,
    toolchain,
  ],
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
    lazygit = { glob = "usr/bin/lazygit" } | OutputBin,
  },
  runtime_deps = [glibc],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "jesseduffield", repo = "lazygit" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Smoke test ported from the Wolfi recipe's test block.
          ["/bin/bash", "-c", "lazygit --help"],
          ["/bin/bash", "-c", "lazygit --version"],
          ["/bin/bash", "-c", "set -euo pipefail\n# Verify buildSource was embedded via ldflags\nlazygit --version 2>&1 | grep -F \"wolfiRelease\""],
        ],
      } | Test,
  },
} | BuildSpec
