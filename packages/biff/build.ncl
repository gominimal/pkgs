let { BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.1.0" in
{
  name = "biff",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/BurntSushi/biff/archive/refs/tags/%{version}.tar.gz",
      sha256 = "2467dddc985a335f83049d19eec862dac7e9dab59044ed2932f8a371a88291f1",
      extract = true,
      strip_prefix = "biff-%{version}",
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
    biff = { glob = "usr/bin/biff" } | OutputLib,
  },
} | BuildSpec
