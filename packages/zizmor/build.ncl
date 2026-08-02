let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.29.0" in
{
  name = "zizmor",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/zizmorcore/zizmor/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "de3da74599a1e080361e97c0431bdc0f656ea530420fdff953a8e3d679e1153b",
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
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "zizmorcore",
        repo = "zizmor",
      },
      build_cost_multiple = 3,
    } | Attrs,
} | BuildSpec
