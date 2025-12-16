let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let libpsl = import "../libpsl/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let perl = import "../perl/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "8.17.0" in
{
  name = "curl",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/curl-%{version}.tar.xz",
      sha256 = "955f6e729ad6b3566260e8fef68620e76ba3c31acf0a18524416a185acf77992",
      extract = true,
      strip_prefix = "curl-%{version}",
    } | Source,
    base,
    make,
    perl,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    libpsl,
    openssl,
    zlib,
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/libcurl.so*" } | OutputLib,

    ltconfigs = { glob = "usr/lib/libcurl.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,

    mans = { glob = "usr/share/man/**" } | OutputData,
    includes = { glob = "usr/include/curl/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "curl",
    } | Attrs,
} | BuildSpec
