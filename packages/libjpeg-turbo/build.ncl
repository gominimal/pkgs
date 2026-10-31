let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.2.1" in
{
  name = "libjpeg-turbo",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://downloads.sourceforge.net/libjpeg-turbo/libjpeg-turbo-3.2.1.tar.gz
      url = "gs://minimal-staging-archives/libjpeg-turbo-%{version}.tar.gz",
      sha256 = "c27ad72a68da151177929aa969ae773a2da5ac2af9ce946079314fdac8cece7f",
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
  attrs =
    {
      upstream_version = version,
      license_spdx = "IJG AND BSD-3-Clause AND Zlib",
      source_provenance = {
        category = 'GithubRepo,
        owner = "libjpeg-turbo",
        repo = "libjpeg-turbo",
      },
    } | Attrs,
} | BuildSpec
