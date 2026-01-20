let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "1.6.53" in
{
  name = "libpng",
  inputs = [
    { file = "build.sh" } | Local,
    {
      # https://downloads.sourceforge.net/libpng/libpng-1.6.53.tar.xz
      url = "gs://minimal-staging-archives/libpng-%{version}.tar.xz",
      sha256 = "1d3fb8ccc2932d04aa3663e22ef5ef490244370f4e568d7850165068778d98d4",
      extract = true,
      strip_prefix = "libpng-%{version}",
    } | Source,
    base,
    toolchain,
    make,
  ],
  runtime_deps = [
    glibc,
    zlib,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libpng*.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "libpng",
    } | Attrs,
} | BuildSpec
