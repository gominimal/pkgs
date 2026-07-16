let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in
let nasm = import "../nasm/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "4.2" in
{
  name = "libx265",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://bitbucket.org/multicoreware/x265_git/downloads/x265_%{version}.tar.gz",
      sha256 = "40b1ea0453e0309f0eba934e0ddf533f8f6295966679e8894e8f1c1c8d5e1210",
      extract = true,
      strip_prefix = "x265_%{version}",
    } | Source,
    base,
    toolchain,
    cmake,
    make,
    nasm,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/x265" } | OutputBin,
    libs = { glob = "usr/lib/libx265.so*" } | OutputLib,
    includes = { glob = "usr/include/x265*.h" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-only",
    } | Attrs,
} | BuildSpec
