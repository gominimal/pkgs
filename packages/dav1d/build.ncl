let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let meson = import "../meson/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let nasm = import "../nasm/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.5.4" in
{
  name = "dav1d",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://downloads.videolan.org/pub/videolan/dav1d/%{version}/dav1d-%{version}.tar.xz",
      sha256 = "686616b7c69eb88d44459391ab25cac13b6647a3b288835c5784e71c1514a5c5",
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
