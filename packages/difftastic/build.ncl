let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.67.0" in
{
  name = "difftastic",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/Wilfred/difftastic/%{version}.tar.gz",
      sha256 = "a6a15d6ca9f9ab7c034d1770417d1829deb3fbe9dcf4731b9cba867e50e78437",
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
