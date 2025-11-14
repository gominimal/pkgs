let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.1.3" in
{
  name = "hexhog",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/DVDTSB/hexhog/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "5858dcb32b3f12647784c9a6ba2e107e157b9a82884bcfed3e994a70c7584b29",
      extract = true,
      strip_prefix = "hexhog-%{version}",
    } | Source,
    base,
    ca-certificates, # TODO: Should probably be on Rust?
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    gcc, # TODO, weird
  ],

  cmd = "./build.sh",

  outputs = {
    hexhog = { glob = "usr/bin/hexhog" } | OutputBin,
  },
  attrs.upstream_version = version,
} | BuildSpec
