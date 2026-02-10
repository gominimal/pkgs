let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "18.11.0" in
{
  name = "atuin",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/atuinsh/atuin/v%{version}.tar.gz",
      sha256 = "9d47c1b176be1c0d4a4c16e94dcb55df9c893ee9d2ad6dbc09b4719d5b557645",
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
