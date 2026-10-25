let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let xorgproto = import "../xorgproto/build.ncl" in

let libx11 = import "../libx11/build.ncl" in
let libxext = import "../libxext/build.ncl" in
let libxfixes = import "../libxfixes/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# X11 Input extension library (libXi.so.6). Pulled in as a runtime dep of
# libxtst (and, transitively, chromium-bin — Chrome links libXi.so.6). Deps
# taken straight from libXi-1.8.4's pkg-config: `Requires.private: x11 xext
# xfixes` (so it links libXfixes too), plus xorgproto for the input/xproto
# headers.
let version = "1.8.4" in
{
  name = "libxi",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libXi-%{version}.tar.xz",
      sha256 = "ddd6057b89a91903bc2f884d55c8467440906945e482c36547260dff28661afc",
      extract = true,
      strip_prefix = "libXi-%{version}",
    } | Source,
    base,
    make,
    toolchain,
    pkgconf,
    xorgproto,
  ],
  runtime_deps = [
    libx11,
    libxext,
    libxfixes,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libXi.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
    } | Attrs,
} | BuildSpec
