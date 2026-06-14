let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.16.0" in
{
  name = "nickel-lsp",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/nickel-lang/nickel/archive/refs/tags/%{version}.tar.gz",
      sha256 = "32a449ebc4d463dd193eb8ce8aced5324655188095e709a9c0addb7b3ceeaec3",
      extract = true,
      strip_prefix = "nickel-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",

  outputs = {
    nls = { glob = "usr/bin/nls" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "nickel-lang",
        repo = "nickel",
      },
      build_cost_multiple = 3,
    } | Attrs,
} | BuildSpec
