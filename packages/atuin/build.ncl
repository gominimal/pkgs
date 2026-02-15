let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "18.12.1" in
{
  name = "atuin",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/atuinsh/atuin/v%{version}.tar.gz",
      sha256 = "8643a7df1e366e9ad3134514b9bcaf4d6440accb13c64340ec9ec1923d58eb6e",
      extract = true,
      strip_prefix = "atuin-%{version}",
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
    atuin = { glob = "usr/bin/atuin" } | OutputBin,
  },
  attrs.upstream_version = version,
} | BuildSpec
