let { BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.3.1" in
{
  name = "ut",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/ksdme/ut/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "1dd4a7efe89056e831889a0c0e2ba7c35f7d8ad78beb16153e819542608958ca",
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
} | BuildSpec
