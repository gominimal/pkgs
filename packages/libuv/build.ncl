let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in
let m4 = import "../m4/build.ncl" in
let automake = import "../automake/build.ncl" in
let autoconf = import "../autoconf/build.ncl" in
let libtool = import "../libtool/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.52.1" in
{
  name = "libuv",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libuv/libuv/v%{version}.tar.gz",
      sha256 = "478baf2599bfbc882c355288c9cb6f92e0e7dda435fa04031fa5b607cf3f414c",
      extract = true,
      strip_prefix = "libuv-%{version}",
    } | Source,
    base,
    toolchain,
    pkgconf,
    make,
    perl,
    m4,
    automake,
    autoconf,
    libtool,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    libs = { glob = "usr/lib/*.{a,so*}" } | OutputLib,

    ltconfigs = { glob = "usr/lib/*.la" } | OutputData,

    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "libuv",
        repo = "libuv",
      },
    } | Attrs,
} | BuildSpec
