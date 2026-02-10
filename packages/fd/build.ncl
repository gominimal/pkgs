let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "10.3.0" in
{
  name = "fd",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/sharkdp/fd/v%{version}.tar.gz",
      sha256 = "2edbc917a533053855d5b635dff368d65756ce6f82ddefd57b6c202622d791e9",
      extract = true,
      strip_prefix = "fd-%{version}",
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
    fd = { glob = "usr/bin/fd" } | OutputBin,
  },
  attrs.upstream_version = version,
} | BuildSpec
