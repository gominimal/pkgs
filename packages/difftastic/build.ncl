let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.65.0" in
{
  name = "difftastic",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/Wilfred/difftastic/archive/refs/tags/%{version}.tar.gz",
      sha256 = "59462f69e2cedfdc1bee4fd0da48fe9a7ae635cdb6818c1a300b31c0b146d4b8",
      extract = true,
      strip_prefix = "difftastic-%{version}",
    } | Source,
    base,
    rust,
    make,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    gcc, # TODO, weird
  ],

  cmd = "./build.sh",

  outputs = {
    difft = { glob = "usr/bin/difft" } | OutputBin,
  },
  attrs.upstream_version = version,
} | BuildSpec
