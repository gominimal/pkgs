let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc-runtime = import "../gcc-runtime/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.13.2" in
{
  name = "hex-patch",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/Etto48/HexPatch/v%{version}.tar.gz",
      sha256 = "5399811ba7ea435d450698243319bd7844a9442300f43a5e384106bdd0f3b652",
      extract = true,
      strip_prefix = "HexPatch-%{version}",
    } | Source,
    base,
    rust,
    make,
    cmake,
    python,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc-runtime ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",

  outputs = {
    hex-patch = { glob = "usr/bin/hex-patch" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "AGPL-3.0-only",
      source_provenance = {
        category = 'GithubRepo,
        owner = "Etto48",
        repo = "HexPatch",
      },
      build_cost_multiple = 2,
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/hex-patch --version",
  },
} | BuildSpec
