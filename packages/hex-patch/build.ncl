let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.12.5" in
{
  name = "hex-patch",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/Etto48/HexPatch/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "089a87c1128483507bef4f89df5ea4e0a7ffe09210b3a9cfa687705f86ea621f",
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
  attrs.upstream_version = version,
} | BuildSpec
