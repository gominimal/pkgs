let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let version = "2.0.0" in
{
  name = "hyperfine",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/sharkdp/hyperfine/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "f4b71df3c78e4cf752ca6fb6ebc4b025f7ea6a5ca5c48fea75f8a1fdb4c7d721",
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
