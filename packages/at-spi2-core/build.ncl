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

let version = "2.60.5" in
{
  name = "at-spi2-core",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/at-spi2-core-%{version}.tar.xz",
      sha256 = "6059a77d507438ff6c8d6d06025f8f9f5774fa0f8eabe9c9b059b1cc41e1bbc0",
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
      license_spdx = "LGPL-2.1-only",
    } | Attrs,
} | BuildSpec
