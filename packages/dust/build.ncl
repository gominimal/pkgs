let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.2.4" in
{
  name = "dust",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/bootandy/dust/v%{version}.tar.gz",
      sha256 = "2f6768534bd01727234e67f1dd3754c9547aa18c715f6ee52094e881ebac50e3",
      extract = true,
      strip_prefix = "dust-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    gcc,
  ],

  cmd = "./build.sh",

  outputs = {
    dust = { glob = "usr/bin/dust" } | OutputBin,
  },
  attrs.upstream_version = version,
} | BuildSpec
