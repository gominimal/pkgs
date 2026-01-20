let { BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.2.30" in
{
  name = "prek",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/j178/prek/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "9721d80a23463bfb6275c6470fd7d0d91ee0167621f4a9d4a7d9a7d850663af3",
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
