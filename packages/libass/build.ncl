let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let fontconfig = import "../fontconfig/build.ncl" in
let freetype = import "../freetype/build.ncl" in
let fribidi = import "../fribidi/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let harfbuzz = import "../harfbuzz/build.ncl" in

let version = "0.17.4" in
{
  name = "libass",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/libass/libass/releases/download/%{version}/libass-%{version}.tar.gz",
      sha256 = "a886b3b80867f437bc55cff3280a652bfa0d37b43d2aff39ddf3c4f288b8c5a8",
      extract = true,
      strip_prefix = "libass-%{version}",
    } | Source,
    base,
    make,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    fontconfig,
    freetype,
    fribidi,
    glibc,
    harfbuzz,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libass.so*" } | OutputLib,
    includes = { glob = "usr/include/ass/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "libass",
        repo = "libass",
      },
    } | Attrs,
} | BuildSpec
