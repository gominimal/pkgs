# Imported from Wolfi `restic` by `pkgmgr import-wolfi` (go build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "0.19.1" in
{
  name = "restic",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/restic/restic/v%{version}.tar.gz",
      sha256 = "bb9b1a19040744d26d8a79be029d4e6b189c45ccc9d8831d7fe367d3c33df725",
      extract = true,
      strip_prefix = "restic-%{version}",
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
    restic = { glob = "usr/bin/restic" } | OutputBin,
  },
  runtime_deps = [glibc],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "restic", repo = "restic" },
      license_spdx = "BSD-2-Clause",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Smoke test ported from the Wolfi recipe's test block.
          ["/bin/bash", "-c", "restic --version"],
          ["/bin/bash", "-c", "restic --help"],
        ],
      } | Test,
  },
} | BuildSpec
