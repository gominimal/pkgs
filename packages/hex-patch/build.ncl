let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.13.1" in
{
  name = "hex-patch",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/Etto48/HexPatch/v%{version}.tar.gz",
      sha256 = "95e36866e2a22616c3642a943038ece6bdfce693284ea91bc3ae4f900ba85f83",
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
    gcc, # TODO, weird
  ],

  cmd = "./build.sh",

  outputs = {
    hex-patch = { glob = "usr/bin/hex-patch" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "Etto48",
        repo = "HexPatch",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
