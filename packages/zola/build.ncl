# Imported from Wolfi `zola` by `pkgmgr import-wolfi` (rust build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let version = "0.23.1" in
{
  name = "zola",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/getzola/zola/v%{version}.tar.gz",
      sha256 = "331240b037bbef0a15e6c1db5a2eb572097f12a362deb075a331dbb849928f83",
      extract = true,
      strip_prefix = "zola-%{version}",
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
    zola = { glob = "usr/bin/zola" } | OutputBin,
  },
  runtime_deps = [glibc, subsetOf gcc ["libgcc"]],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "getzola", repo = "zola" },
      # zola relicensed to EUPL-1.2 at v0.22 (commit 3c9131d); v0.23.1 declares
      # `license = "EUPL-1.2"` in Cargo.toml and ships only the EUPL LICENSE file.
      license_spdx = "EUPL-1.2",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Smoke test ported from the Wolfi recipe's test block.
          ["/bin/bash", "-c", "zola --version"],
          ["/bin/bash", "-c", "zola --help"],
        ],
      } | Test,
  },
} | BuildSpec
