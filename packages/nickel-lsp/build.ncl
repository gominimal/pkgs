let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.17.0" in
{
  name = "nickel-lsp",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/nickel-lang/nickel/archive/refs/tags/%{version}.tar.gz",
      sha256 = "8cc47b3a2b9ed4e3b7fca06f36a8a295d231e9f8bb112d0cc02081583c189f75",
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
