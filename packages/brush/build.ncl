let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.3.0" in
{
  name = "brush",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/reubeno/brush/brush-shell-v%{version}.tar.gz",
      sha256 = "a0dac5cf7e9d8bced9bf28ed400955750ed6b7320d1154522a14f4a74e75a056",
      extract = true,
      strip_prefix = "brush-brush-shell-v%{version}",
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
    brush = { glob = "usr/bin/brush" } | OutputBin,
  },
  attrs.upstream_version = version,
} | BuildSpec
