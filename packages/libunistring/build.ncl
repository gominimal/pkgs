let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.4.1" in
{
  name = "libunistring",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libunistring-%{version}.tar.xz",
      sha256 = "67d88430892527861903788868c77802a217b0959990f7449f2976126a307763",
      extract = true,
      strip_prefix = "libunistring-%{version}",
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
    libs = { glob = "usr/lib/*.{a,so*}" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    repology_project = "libunistring",
  } | Attrs,
} | BuildSpec
