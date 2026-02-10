let { BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.6.0" in
{
  name = "ut",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/ksdme/ut/v%{version}.tar.gz",
      sha256 = "f9fd00d8913d15cae4f0124507cfdf95375be98a0d14522b5d58204dca0a0e69",
      extract = true,
      strip_prefix = "ut-%{version}",
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
    ut = { glob = "usr/bin/ut" } | OutputLib,
  },
  attrs.upstream_version = version,
} | BuildSpec
