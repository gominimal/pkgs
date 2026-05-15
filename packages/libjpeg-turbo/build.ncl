let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.1.4.1" in
{
  name = "libjpeg-turbo",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://downloads.sourceforge.net/libjpeg-turbo/libjpeg-turbo-3.1.4.1.tar.gz
      url = "gs://minimal-staging-archives/libjpeg-turbo-%{version}.tar.gz",
      sha256 = "ecae8008e2cc9ade2f2c1bb9d5e6d4fb73e7c433866a056bd82980741571a022",
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
      source_provenance = {
        category = 'GithubRepo,
        owner = "libjpeg-turbo",
        repo = "libjpeg-turbo",
      },
    } | Attrs,
} | BuildSpec
