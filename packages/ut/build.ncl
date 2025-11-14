let { BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.5.0" in
{
  name = "ut",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/ksdme/ut/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "9d48c738e8f238faddca6db16f9d02668b6942ad8a90748d6f9df7538eefcb3d",
      extract = true,
      strip_prefix = "ut-%{version}",
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
    ut = { glob = "usr/bin/ut" } | OutputLib,
  },
  attrs.upstream_version = version,
} | BuildSpec
