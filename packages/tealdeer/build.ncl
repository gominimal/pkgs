# Imported from Wolfi `tealdeer` by `pkgmgr import-wolfi` (rust build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let version = "1.8.1" in
{
  name = "tealdeer",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/tealdeer-rs/tealdeer/v%{version}.tar.gz",
      sha256 = "8b9ea7ef8dd594d6fb8b452733b0c883a68153cec266b23564ce185bdf22fcfa",
      extract = true,
      strip_prefix = "tealdeer-%{version}",
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
    tldr = { glob = "usr/bin/tldr" } | OutputBin,
  },
  runtime_deps = [glibc, subsetOf gcc ["libgcc"]],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "tealdeer-rs", repo = "tealdeer" },
      license_spdx = "Apache-2.0",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Smoke test ported from the Wolfi recipe's test block.
          ["/bin/bash", "-c", "tldr --version"],
          ["/bin/bash", "-c", "tldr --help"],
        ],
      } | Test,
  },
} | BuildSpec
