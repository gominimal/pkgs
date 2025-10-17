let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.1.2" in
{
  name = "hexhog",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/DVDTSB/hexhog/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "9c417bd665c613760c875caecf32ccf37543af7c165c2dc055bf73c6fa8bf6f0",
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
} | BuildSpec
