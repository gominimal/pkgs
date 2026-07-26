let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in

let openssl = import "../openssl/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.4.19" in
{
  name = "cups",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/cups-%{version}-source.tar.gz",
      sha256 = "820984b12a67f98705785aae2dd1347fe0ac097828001d4583ff64574aed6389",
      extract = true,
      strip_prefix = "cups-%{version}",
    } | Source,
    base,
    make,
    toolchain,
    pkgconf,
  ],
  runtime_deps = [
    openssl,
    zlib,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libcups*.so*" } | OutputLib,
    includes = { glob = "usr/include/cups/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "OpenPrinting",
        repo = "cups",
      },
    } | Attrs,
} | BuildSpec
