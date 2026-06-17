let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let meson = import "../meson/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let nasm = import "../nasm/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.5.3" in
{
  name = "dav1d",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://downloads.videolan.org/pub/videolan/dav1d/%{version}/dav1d-%{version}.tar.xz",
      sha256 = "732010aa5ef461fa93355ed2c6c5fedb48ddc4b74e697eaabe8907eaeb943011",
      extract = true,
      strip_prefix = "dav1d-%{version}",
    } | Source,
    base,
    meson,
    nasm,
    ninja,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/dav1d" } | OutputBin,
    libs = { glob = "usr/lib/libdav1d.so*" } | OutputLib,
    includes = { glob = "usr/include/dav1d/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-2-Clause",
    } | Attrs,
} | BuildSpec
