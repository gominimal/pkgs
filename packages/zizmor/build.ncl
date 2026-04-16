let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.24.1" in
{
  name = "zizmor",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/zizmorcore/zizmor/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "4a037cd9ccdebdcf02e508f248c5ee8656ebf024d8f29d2c458498f16fe9893b",
      extract = true,
      strip_prefix = "zizmor-%{version}",
    } | Source,
    base,
    make,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
  ],

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    zizmor = { glob = "usr/bin/zizmor" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "zizmorcore",
        repo = "zizmor",
      },
      build_cost_multiple = 3,
    } | Attrs,
} | BuildSpec
