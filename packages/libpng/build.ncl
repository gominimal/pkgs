let { BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.6.50" in
{
  name = "libpng",
  inputs = [
    { file = "build.sh" } | Local,
    {
      # https://downloads.sourceforge.net/libpng/libpng-1.6.50.tar.xz
      url = "gs://minimal-staging-archives/libpng-%{version}.tar.xz",
      sha256 = "4df396518620a7aa3651443e87d1b2862e4e88cad135a8b93423e01706232307",
      extract = true,
      strip_prefix = "libpng-%{version}",
    } | Source,
    base,
    toolchain,
    make,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    libs = { glob = "usr/lib/libpng*.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
  },
  attrs.upstream_version = version,
} | BuildSpec
