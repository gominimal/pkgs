let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let meson = import "../meson/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in

let harfbuzz = import "../harfbuzz/build.ncl" in
let fribidi = import "../fribidi/build.ncl" in
let glib = import "../glib/build.ncl" in
let fontconfig = import "../fontconfig/build.ncl" in
let freetype = import "../freetype/build.ncl" in
let cairo = import "../cairo/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.58.0" in
{
  name = "pango",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/pango-%{version}.tar.xz",
      sha256 = "bc5bad6213ad4886a47d1e80292fd850b64159b50db67917a43d9ea80ee2298a",
      extract = true,
      strip_prefix = "pango-%{version}",
    } | Source,
    base,
    meson,
    ninja,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    harfbuzz,
    fribidi,
    glib,
    fontconfig,
    freetype,
    cairo,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libpango*.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "LGPL-2.0-only",
    } | Attrs,
} | BuildSpec
