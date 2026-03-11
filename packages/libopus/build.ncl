let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.6.1" in
{
  name = "libopus",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://downloads.xiph.org/releases/opus/opus-%{version}.tar.gz",
      sha256 = "6ffcb593207be92584df15b32466ed64bbec99109f007c82205f0194572411a1",
      extract = true,
      strip_prefix = "opus-%{version}",
    } | Source,
    base,
    toolchain,
    make,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    libs = { glob = "usr/lib/libopus.so*" } | OutputLib,
    includes = { glob = "usr/include/opus/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "xiph",
        repo = "opus",
      },
    } | Attrs,
} | BuildSpec
