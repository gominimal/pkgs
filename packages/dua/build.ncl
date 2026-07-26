# Imported from Wolfi `dua` by `pkgmgr import-wolfi` (rust build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let version = "2.38.1" in
{
  name = "dua",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/Byron/dua-cli/v%{version}.tar.gz",
      sha256 = "b30d76e60be8f4928c3b7d5c3cd2d9034d60ad09c7e044bf2056f01e8596f46e",
      extract = true,
      strip_prefix = "dua-cli-%{version}",
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
    dua = { glob = "usr/bin/dua" } | OutputBin,
  },
  runtime_deps = [glibc, subsetOf gcc ["libgcc"]],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "Byron", repo = "dua-cli" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Smoke test ported from the Wolfi recipe's test block.
          ["/bin/bash", "-c", "dua -V\ndua --version\ndua --help"],
        ],
      } | Test,
  },
} | BuildSpec
