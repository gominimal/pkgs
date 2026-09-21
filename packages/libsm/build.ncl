let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let xorgproto = import "../xorgproto/build.ncl" in
let xtrans = import "../xtrans/build.ncl" in
let libice = import "../libice/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# X Session Management library (libSM.so.6), required by libXt. Deps from libSM's pkg-config:
# `Requires.private: ice xproto`, plus xtrans. Built without libuuid: session ids fall back to the
# ICE network id.
let version = "1.2.6" in
{
  name = "libsm",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libSM-%{version}.tar.xz",
      sha256 = "be7c0abdb15cbfd29ac62573c1c82e877f9d4047ad15321e7ea97d1e43d835be",
      extract = true,
      strip_prefix = "libSM-%{version}",
    } | Source,
    base,
    make,
    toolchain,
    pkgconf,
    xorgproto,
    xtrans,
    libice,
  ],
  runtime_deps = [
    libice,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libSM.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
    } | Attrs,
} | BuildSpec
