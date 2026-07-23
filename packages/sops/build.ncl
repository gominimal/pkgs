# Imported from Wolfi `sops` by `pkgmgr import-wolfi` (go build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "3.13.3" in
{
  name = "sops",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/getsops/sops/v%{version}.tar.gz",
      sha256 = "49811c5ed80f6b4d4e98cef98e3f7378406aa692fd773dfb72ad1b4dfb940448",
      extract = true,
      strip_prefix = "sops-%{version}",
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
    sops = { glob = "usr/bin/sops" } | OutputBin,
  },
  runtime_deps = [glibc],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "getsops", repo = "sops" },
      license_spdx = "MPL-2.0",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Smoke test ported from the Wolfi recipe's test block.
          ["/bin/bash", "-c", "sops --version\nsops --help"],
        ],
      } | Test,
  },
} | BuildSpec
