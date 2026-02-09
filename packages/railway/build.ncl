let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "4.29.0" in
{
  name = "railway",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/railwayapp/cli/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "a355f0fbed7784751332b52a03d6cf5e1cf434f38d0a953c5fb548e3cbef4866",
      extract = true,
      strip_prefix = "cli-%{version}",
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
    railway = { glob = "usr/bin/railway" } | OutputBin,
  },
  attrs.upstream_version = version,
} | BuildSpec
