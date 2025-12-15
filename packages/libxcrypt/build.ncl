let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "4.5.2" in
{
  name = "libxcrypt",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libxcrypt-%{version}.tar.xz",
      sha256 = "71513a31c01a428bccd5367a32fd95f115d6dac50fb5b60c779d5c7942aec071",
      extract = true,
      strip_prefix = "libxcrypt-%{version}",
    } | Source,
    base,
    perl,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    libs = { glob = "usr/lib/*.so*" } | OutputLib,

    ltconfigs = { glob = "usr/lib/*.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,

    mans = { glob = "usr/share/man/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    repology_project = "libxcrypt",
  } | Attrs,
} | BuildSpec
