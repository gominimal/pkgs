let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.69.0" in
{
  name = "difftastic",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/Wilfred/difftastic/%{version}.tar.gz",
      sha256 = "49d722fb80a0324ea99fe11907f796cde635443084d15cc6f1afd9e0de54bde0",
      extract = true,
      strip_prefix = "difftastic-%{version}",
    } | Source,
    base,
    rust,
    make,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",

  outputs = {
    difft = { glob = "usr/bin/difft" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "Wilfred",
        repo = "difftastic",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
