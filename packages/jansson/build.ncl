let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "2.14" in
{
  name = "jansson",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/akheron/jansson/releases/download/v%{version}/jansson-%{version}.tar.gz",
      sha256 = "5798d010e41cf8d76b66236cfb2f2543c8d082181d16bc3085ab49538d4b9929",
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
