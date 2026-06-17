let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let nasm = import "../nasm/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let commit = "b35605ace3ddf7c1a5d67a2eb553f034aef41d55" in
let version = "0.165.3222" in
{
  name = "libx264",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://code.videolan.org/videolan/x264/-/archive/%{commit}/x264-%{commit}.tar.bz2",
      sha256 = "6eeb82934e69fd51e043bd8c5b0d152839638d1ce7aa4eea65a3fedcf83ff224",
      extract = true,
      strip_prefix = "x264-%{commit}",
    } | Source,
    base,
    toolchain,
    make,
    nasm,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    libs = { glob = "usr/lib/libx264.so*" } | OutputLib,
    includes = { glob = "usr/include/*.h" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-only",
    } | Attrs,
} | BuildSpec
