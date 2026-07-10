# Auto-bootstrapped from https://github.com/sharkdp/hexyl by `pkgmgr bootstrap` (rust build).
# TODO: REVIEWER — verify outputs/runtime_deps + the build.sh.
let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let version = "0.17.0" in
{
  name = "hexyl",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/sharkdp/hexyl/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "72fa17397ad187eec6b295d02c7caabbb209a6e0d5706187b8a599bd5df8615e",
      extract = true,
      strip_prefix = "hexyl-%{version}",
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
    hexyl = { glob = "usr/bin/hexyl" } | OutputBin,
  },
  runtime_deps = [glibc, subsetOf gcc ["libgcc"]],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "sharkdp", repo = "hexyl" },
      license_spdx = "Apache-2.0",
    } | Attrs,
} | BuildSpec
