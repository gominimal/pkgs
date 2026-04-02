let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let libjpeg-turbo = import "../libjpeg-turbo/build.ncl" in
let libpng = import "../libpng/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "1.6.0" in
{
  name = "libwebp",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/webmproject/libwebp/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "93a852c2b3efafee3723efd4636de855b46f9fe1efddd607e1f42f60fc8f2136",
      extract = true,
      strip_prefix = "libwebp-%{version}",
    } | Source,
    base,
    cmake,
    make,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    libjpeg-turbo,
    libpng,
    zlib,
  ],

  cmd = "./build.sh",

  outputs = {
    dwebp = { glob = "usr/bin/dwebp" } | OutputBin,
    webpinfo = { glob = "usr/bin/webpinfo" } | OutputBin,
    webpmux = { glob = "usr/bin/webpmux" } | OutputBin,
    cwebp = { glob = "usr/bin/cwebp" } | OutputBin,
    libs = { glob = "usr/lib/lib*.so*" } | OutputLib,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    source_provenance = {
      category = 'GithubRepo,
      owner = "webmproject",
      repo = "libwebp",
    },
  },
} | BuildSpec
