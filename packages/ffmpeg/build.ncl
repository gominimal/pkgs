let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let freetype = import "../freetype/build.ncl" in
let fontconfig = import "../fontconfig/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let xz = import "../xz/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "8.0.1" in
{
  name = "ffmpeg",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://ffmpeg.org/releases/ffmpeg-%{version}.tar.xz",
      sha256 = "05ee0b03119b45c0bdb4df654b96802e909e0a752f72e4fe3794f487229e5a41",
      extract = true,
      strip_prefix = "ffmpeg-%{version}",
    } | Source,
    base,
    make,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    freetype,
    fontconfig,
    openssl,
    xz,
    zlib,
  ],

  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/lib*.so*" } | OutputLib,

    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "ffmpeg",
      source_provenance = {
        category = 'GithubRepo,
        owner = "FFmpeg",
        repo = "FFmpeg",
      },
    } | Attrs,
} | BuildSpec
