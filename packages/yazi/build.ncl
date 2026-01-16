let { Attrs, BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "26.1.4" in
{
  name = "yazi",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/sxyazi/yazi/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "17839410a2865dc6ddb40da4b034dbf2729602fc325d07ad4df7dbc354c94c9e",
      extract = true,
      strip_prefix = "yazi-%{version}",
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
    yazi = { glob = "usr/bin/yazi" } | OutputLib,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "yazi",
    } | Attrs,
} | BuildSpec
