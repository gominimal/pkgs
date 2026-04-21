let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "1.6.58" in
{
  name = "libpng",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://downloads.sourceforge.net/libpng/libpng-1.6.58.tar.xz
      url = "gs://minimal-staging-archives/libpng-%{version}.tar.xz",
      sha256 = "28eb403f51f0f7405249132cecfe82ea5c0ef97f1b32c5a65828814ae0d34775",
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
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "libpng",
      source_provenance = {
        category = 'GithubRepo,
        owner = "pnggroup",
        repo = "libpng",
      },
    } | Attrs,
} | BuildSpec
