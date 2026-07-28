let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let version = "1.20.0" in
{
  name = "hyperfine",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/sharkdp/hyperfine/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "f90c3b096af568438be7da52336784635a962c9822f10f98e5ad11ae8c7f5c64",
      extract = true,
      strip_prefix = "hyperfine-%{version}",
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
    hyperfine = { glob = "usr/bin/hyperfine" } | OutputBin,
  },
  runtime_deps = [glibc, subsetOf gcc ["libgcc"]],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "sharkdp", repo = "hyperfine" },
      license_spdx = "Apache-2.0",
    } | Attrs,
} | BuildSpec
