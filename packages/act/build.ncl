# Imported from Wolfi `act` by `pkgmgr import-wolfi` (go build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "0.2.89" in
{
  name = "act",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/nektos/act/v%{version}.tar.gz",
      sha256 = "649cd5b91cad870871d2283fb3ad95c8fa1d5ced7a1db8d7b346d1a7dcd3ec71",
      extract = true,
      strip_prefix = "act-%{version}",
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
  outputs = {
    act = { glob = "usr/bin/act" } | OutputBin,
  },
  runtime_deps = [glibc],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "nektos", repo = "act" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Smoke test ported from the Wolfi recipe's test block.
          ["/bin/bash", "-c", "act --version"],
          ["/bin/bash", "-c", "act --help"],
        ],
      } | Test,
  },
} | BuildSpec
