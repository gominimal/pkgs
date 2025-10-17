let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.1.4" in
{
  name = "imgcatr",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/SilinMeng0510/imgcatr/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "8e59a4ad83d1b474372fb8c5c1f11f07c742ea9443c26a9f02a4465140026f0e",
      extract = true,
      strip_prefix = "imgcatr-%{version}",
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
    imgcatr = { glob = "usr/bin/imgcatr" } | OutputBin,
  },
} | BuildSpec
