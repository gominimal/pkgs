let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let sed = import "../sed/build.ncl" in
let make = import "../make/build.ncl" in
let libpng = import "../libpng/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.14.3" in
{
  name = "freetype",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://downloads.sourceforge.net/freetype/freetype-2.14.3.tar.xz
      url = "gs://minimal-staging-archives/freetype-%{version}.tar.xz",
      sha256 = "36bc4f1cc413335368ee656c42afca65c5a3987e8768cc28cf11ba775e785a5f",
      extract = true,
      strip_prefix = "freetype-%{version}",
    } | Source,
    base,
    toolchain,
    sed,
    make,
  ],
  runtime_deps = [
    glibc,
    libpng,
  ],

  cmd = "./build.sh",

  outputs = {
    freetype-config = { glob = "usr/bin/freetype-config", allow_missing_interpreter = true } | OutputBin,

    libs = { glob = "usr/lib/libfreetype*.so*" } | OutputLib,

    ltconfigs = { glob = "usr/lib/**/*.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,

    mans = { glob = "usr/share/man/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },
  attrs.upstream_version = version,
  attrs.license_spdx = "FTL OR GPL-2.0-or-later",
} | BuildSpec
