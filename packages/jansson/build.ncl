let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "2.15.1" in
{
  name = "jansson",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/akheron/jansson/releases/download/v%{version}/jansson-%{version}.tar.gz",
      sha256 = "0c7114dc0b2d22a670724a1f95922029d7077c19dbf79a584cb8084d2f267f2f",
      extract = true,
      strip_prefix = "jansson-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libjansson.so*" } | OutputLib,
    includes = { glob = "usr/include/jansson*.h" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "akheron",
        repo = "jansson",
      },
    } | Attrs,
} | BuildSpec
