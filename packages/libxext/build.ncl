let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let xorgproto = import "../xorgproto/build.ncl" in

let libx11 = import "../libx11/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.3.6" in
{
  name = "libxext",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libXext-%{version}.tar.xz",
      sha256 = "edb59fa23994e405fdc5b400afdf5820ae6160b94f35e3dc3da4457a16e89753",
      extract = true,
      strip_prefix = "libXext-%{version}",
    } | Source,
    base,
    make,
    toolchain,
    pkgconf,
    xorgproto,
  ],
  runtime_deps = [
    libx11,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libXext.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "test -f /usr/lib/libXext.so.6 || test -f /usr/lib/x86_64-linux-gnu/libXext.so.6"],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
