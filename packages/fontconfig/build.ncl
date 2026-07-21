let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let python = import "../python/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let make = import "../make/build.ncl" in
let gperf = import "../gperf/build.ncl" in

let bzip2 = import "../bzip2/build.ncl" in
let expat = import "../expat/build.ncl" in
let freetype = import "../freetype/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "2.18.2" in
{
  name = "fontconfig",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/2.17.1/fontconfig-2.18.2.tar.xz
      url = "gs://minimal-staging-archives/fontconfig-%{version}.tar.xz",
      sha256 = "cf8e6576ef0484c15079bdaf77cd9c51c464df5365814ada4d3ee7331ea31eb5",
      extract = true,
      strip_prefix = "fontconfig-%{version}",
    } | Source,
    base,
    toolchain,
    python,
    pkgconf,
    make,
    gperf,
  ],
  runtime_deps = [
    bzip2,
    expat,
    glibc,
    freetype,
    zlib,
  ],

  cmd = "./build.sh",

  outputs = {
    bins = { glob = "usr/bin/fc-*" } | OutputBin,
    libs = { glob = "usr/lib/libfontconfig*.so*" } | OutputLib,

    ltconfigs = { glob = "usr/lib/**/*.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,

    fc-data = { glob = "{etc,usr/share/fontconfig}/**" } | OutputData,
  },
  attrs.upstream_version = version,
  attrs.license_spdx = "HPND-sell-variant",
} | BuildSpec
