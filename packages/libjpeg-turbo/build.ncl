let { BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.0.1" in
{
  name = "libjpeg-turbo",
  inputs = [
    { file = "build.sh" } | Local,
    {
      # https://downloads.sourceforge.net/libjpeg-turbo/libjpeg-turbo-3.0.1.tar.gz
      url = "gs://minimal-staging-archives/libjpeg-turbo-%{version}.tar.gz",
      sha256 = "22429507714ae147b3acacd299e82099fce5d9f456882fc28e252e4579ba2a75",
      extract = true,
      strip_prefix = "libjpeg-turbo-%{version}",
    } | Source,
    base,
    toolchain,
    make,
    cmake,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    libs = { glob = "usr/lib/lib*.so*" } | OutputLib,

    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },
  attrs.upstream_version = version,
} | BuildSpec
