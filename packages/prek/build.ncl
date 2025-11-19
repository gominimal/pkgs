let { BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.2.17" in
{
  name = "prek",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/j178/prek/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "32ebc2c2dbdce9b7906b23550ed55a3eb50672a01bd52ede9fa50ca1f3c28484",
      extract = true,
      strip_prefix = "prek-%{version}",
    } | Source,
    base,
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
