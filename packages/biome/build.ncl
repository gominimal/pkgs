let { standaloneTest, subsetOf, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.5.8" in
{
  name = "biome",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/biomejs/biome/archive/refs/tags/@biomejs/biome@%{version}.tar.gz",
      sha256 = "f380dead10231f4c2a26c16ad519553c3a4ae6a24e43faaab2cefafe41074577",
      extract = true,
      strip_prefix = "biome--biomejs-biome-%{version}",
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

  outputs = {
    bins = { glob = "usr/bin/biome" } | OutputBin,
  },

  needs = {
    internet = {},
  },

  attrs = {
    upstream_version = version,
    license_spdx = "MIT OR Apache-2.0",
    source_provenance = {
      category = 'GithubRepo,
      owner = "biomejs",
      repo = "biome",
    },
  },

  tests = {
    smoketest = standaloneTest "/usr/bin/biome --version",
  },
} | BuildSpec
