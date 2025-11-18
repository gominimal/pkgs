let { BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.2.15" in
{
  name = "prek",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/j178/prek/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "1af34eb6bf3beb19b73b334f63f77c9225b1c6d57a5bdb53752ad06135843396",
      extract = true,
      strip_prefix = "prek-%{version}",
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
    prek = { glob = "usr/bin/prek" } | OutputLib,
  },
  attrs.upstream_version = version,
} | BuildSpec
