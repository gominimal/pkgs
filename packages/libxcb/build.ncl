let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let xcb-proto = import "../xcb-proto/build.ncl" in
let xorgproto = import "../xorgproto/build.ncl" in
let python = import "../python/build.ncl" in

let libxau = import "../libxau/build.ncl" in
let libxdmcp = import "../libxdmcp/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.17.0" in
{
  name = "libxcb",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libxcb-%{version}.tar.xz",
      sha256 = "599ebf9996710fea71622e6e184f3a8ad5b43d0e5fa8c4e407123c88a59a6d55",
      extract = true,
      strip_prefix = "libxcb-%{version}",
    } | Source,
    base,
    make,
    toolchain,
    pkgconf,
    xcb-proto,
    xorgproto,
    python,
  ],
  runtime_deps = [
    libxau,
    libxdmcp,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libxcb*.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "test -f /usr/lib/libxcb.so.1 || test -f /usr/lib/x86_64-linux-gnu/libxcb.so.1"],
        ],
      } | Test,
  },
  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
