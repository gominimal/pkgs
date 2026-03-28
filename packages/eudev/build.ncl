let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gperf = import "../gperf/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "3.2.14" in
{
  name = "eudev",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/eudev-project/eudev/releases/download/v%{version}/eudev-%{version}.tar.gz",
      sha256 = "8da4319102f24abbf7fff5ce9c416af848df163b29590e666d334cc1927f006f",
      extract = true,
      strip_prefix = "eudev-%{version}",
    } | Source,
    base,
    gperf,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libudev.so*" } | OutputLib,
    includes = { glob = "usr/include/libudev.h" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/libudev.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "eudev-project",
        repo = "eudev",
      },
    } | Attrs,
} | BuildSpec
