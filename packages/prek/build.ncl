let { BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.3.0" in
{
  name = "prek",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/j178/prek/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "6e4e8c342cc03177d771f970cde99995387aa07694e8667e511f5e6c9adb0c02",
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
