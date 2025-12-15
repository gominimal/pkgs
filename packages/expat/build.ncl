let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.7.3" in
{
  name = "expat",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/expat-%{version}.tar.xz",
      sha256 = "71df8f40706a7bb0a80a5367079ea75d91da4f8c65c58ec59bcdfbf7decdab9f",
      extract = true,
      strip_prefix = "expat-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    xmlwf = { glob = "usr/bin/xmlwf" } | OutputBin,

    libexpat = { glob = "usr/lib/libexpat.so*" } | OutputLib,

    includes = { glob = "usr/include/expat*.h" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/expat.pc" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    repology_project = "expat",
  } | Attrs,
} | BuildSpec
