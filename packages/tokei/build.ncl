let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let version = "15.0.0" in
{
  name = "tokei",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/XAMPPRocky/tokei/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "966da7b9a81ac6cb777b9f159f4c02e5b83a8b8bd30ebf5991007839926b600c",
      extract = true,
      strip_prefix = "tokei-%{version}",
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
    tokei = { glob = "usr/bin/tokei" } | OutputBin,
  },
  runtime_deps = [glibc, subsetOf gcc ["libgcc"]],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "XAMPPRocky", repo = "tokei" },
      license_spdx = "MIT OR Apache-2.0",
    } | Attrs,
} | BuildSpec
