let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let xorgproto = import "../xorgproto/build.ncl" in
let libx11 = import "../libx11/build.ncl" in
let libsm = import "../libsm/build.ncl" in
let libice = import "../libice/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# X Toolkit Intrinsics library (libXt.so.6). OpenJDK 7's AWT (icedtea-7) links it. Deps from
# libXt's pkg-config: `Requires: x11 sm ice xproto kbproto`.
let version = "1.3.1" in
{
  name = "libxt",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libXt-%{version}.tar.xz",
      sha256 = "e0a774b33324f4d4c05b199ea45050f87206586d81655f8bef4dba434d931288",
      extract = true,
      strip_prefix = "libXt-%{version}",
    } | Source,
    base,
    make,
    toolchain,
    pkgconf,
    xorgproto,
    libx11,
    libsm,
    libice,
  ],
  runtime_deps = [
    libx11,
    libsm,
    libice,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libXt.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
    } | Attrs,
} | BuildSpec
