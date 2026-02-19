let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .., } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in

let lcms2 = import "../lcms2/build.ncl" in
let libpng = import "../libpng/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.5.4" in
{
  name = "openjpeg",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/uclouvain/openjpeg/archive/v%{version}/openjpeg-%{version}.tar.gz",
      sha256 = "a695fbe19c0165f295a8531b1e4e855cd94d0875d2f88ec4b61080677e27188a",
      extract = true,
      strip_prefix = "openjpeg-%{version}",
    } | Source,
    base,
    toolchain,
    make,
    cmake,
  ],
  runtime_deps = [
    lcms2,
    libpng,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/libopenjp2*.so*" } | OutputLib,

    cmake_data = { glob = "usr/lib/cmake/**/*" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,

    includes = { glob = "usr/include/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "uclouvain",
        repo = "openjpeg",
      },
    } | Attrs,
} | BuildSpec
