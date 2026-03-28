let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let meson = import "../meson/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in

let glib = import "../glib/build.ncl" in
let dbus = import "../dbus/build.ncl" in
let libxml2 = import "../libxml2/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.54.2" in
{
  name = "at-spi2-core",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/at-spi2-core-%{version}.tar.xz",
      sha256 = "510e1760a27ce9ce27a300f116d9b8a7dc8eac1f78714915685833643cb36236",
      extract = true,
      strip_prefix = "at-spi2-core-%{version}",
    } | Source,
    base,
    meson,
    ninja,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    glib,
    dbus,
    libxml2,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/lib{atspi,atk-bridge-2.0}.so*" } | OutputLib,
    includes = { glob = "usr/include/at-spi*/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/{atk-bridge*,atspi*}.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
