let { BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.2.25" in
{
  name = "prek",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/j178/prek/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "0b8e342fc2ffba1d69a3d2bf35f575b0c7bb8404ad2bdf981ca502175ec9d092",
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
