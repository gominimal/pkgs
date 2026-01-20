let { BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let make = import "../make/build.ncl" in

let glibc = import "../glibc/build.ncl" in
{
  name = "libpipeline",
  inputs = [
    { file = "build.sh" } | Local,
    {
      # https://download.savannah.gnu.org/releases/libpipeline/libpipeline-1.5.8.tar.gz
      url = "gs://minimal-staging-archives/libpipeline-1.5.8.tar.gz",
      sha256 = "1b1203ca152ccd63983c3f2112f7fe6fa5afd453218ede5153d1b31e11bb8405",
    } | Source,
    base,
    toolchain,
    make,
    pkgconf,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    libs = { glob = "usr/lib/*.so*" } | OutputLib,
    pkgconf = { glob = "usr/lib/pkgconfig/libpipeline.pc" } | OutputData,
    includes = { glob = "usr/include/*.h" } | OutputData,
    docs = { glob = "usr/share/man/man3/*" } | OutputData,
  },
} | BuildSpec
