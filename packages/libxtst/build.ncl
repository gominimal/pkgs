let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let xorgproto = import "../xorgproto/build.ncl" in

let libx11 = import "../libx11/build.ncl" in
let libxext = import "../libxext/build.ncl" in
let libxi = import "../libxi/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# X11 Testing extension library (libXtst.so.6) — provides XTest/XRecord.
# Chrome links libXtst.so.6 directly, so chromium-bin needs it in its runtime
# closure (147→151 surfaced this: 151 fails to even print --version without it).
# Deps from libXtst-1.2.5's pkg-config: `Requires.private: x11 xext xextproto
# xi` (so it links libXi too), plus xorgproto for the record/xext headers.
let version = "1.2.5" in
{
  name = "libxtst",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libXtst-%{version}.tar.xz",
      sha256 = "b50d4c25b97009a744706c1039c598f4d8e64910c9fde381994e1cae235d9242",
      extract = true,
      strip_prefix = "libXtst-%{version}",
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
    libxi,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libXtst.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
    } | Attrs,
} | BuildSpec
