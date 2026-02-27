let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let xorgproto = import "../xorgproto/build.ncl" in

let libxrender = import "../libxrender/build.ncl" in
let libxext = import "../libxext/build.ncl" in
let libx11 = import "../libx11/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.5.4" in
{
  name = "libxrandr",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libXrandr-%{version}.tar.xz",
      sha256 = "1ad5b065375f4a85915aa60611cc6407c060492a214d7f9daf214be752c3b4d3",
      extract = true,
      strip_prefix = "libXrandr-%{version}",
    } | Source,
    base,
    make,
    toolchain,
    pkgconf,
    xorgproto,
  ],
  runtime_deps = [
    libxrender,
    libxext,
    libx11,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libXrandr.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "test -f /usr/lib/libXrandr.so.2 || test -f /usr/lib/x86_64-linux-gnu/libXrandr.so.2"],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
