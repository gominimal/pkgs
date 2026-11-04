# Imported from Wolfi `croc` by `pkgmgr import-wolfi` (go build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "11.6.3" in
{
  name = "croc",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/schollz/croc/v%{version}.tar.gz",
      sha256 = "41f5c334be83978fea3f6c90d9b77320db3b381bc65ab57d684c091dd6a1d964",
      extract = true,
      strip_prefix = "croc-%{version}",
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
    croc = { glob = "usr/bin/croc" } | OutputBin,
  },
  runtime_deps = [glibc],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "schollz", repo = "croc" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Smoke test ported from the Wolfi recipe's test block.
          ["/bin/bash", "-c", "croc --version"],
          ["/bin/bash", "-c", "croc --help"],
        ],
      } | Test,
  },
} | BuildSpec
