let { BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in

let freetype = import "../freetype/build.ncl" in
let lcms2 = import "../lcms2/build.ncl" in
let libpng = import "../libpng/build.ncl" in
let libjpeg-turbo = import "../libjpeg-turbo/build.ncl" in
let openjpeg = import "../openjpeg/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "10.06.0" in
{
  name = "ghostscript",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs10060/ghostscript-%{version}.tar.xz",
      sha256 = "64352648c2c081c8a9fb1a12dc1965e01ead7c57f58b72d1b54f6ef1cef3c561",
      extract = true,
      strip_prefix = "ghostscript-%{version}",
    } | Source,
    base,
    toolchain,
    make,
    pkgconf,
  ],
  runtime_deps = [
    freetype,
    lcms2,
    libpng,
    libjpeg-turbo,
    openjpeg,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,

    ghostscript_data = { glob = "usr/share/ghostscript/**" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },
  attrs.upstream_version = version,
} | BuildSpec
