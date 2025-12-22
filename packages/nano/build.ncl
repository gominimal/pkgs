let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let file = import "../file/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "8.7" in
{
  name = "nano",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/nano-%{version}.tar.xz",
      sha256 = "afd287aa672c48b8e1a93fdb6c6588453d527510d966822b687f2835f0d986e9",
      extract = true,
      strip_prefix = "nano-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    file,
    ncurses,
    zlib,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bin = { glob = "usr/bin/nano" } | OutputBin,
    languages = { glob = "usr/share/nano/*" } | OutputData,
    man = { glob = "usr/share/man/**/*" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "nano",
    } | Attrs,
} | BuildSpec
