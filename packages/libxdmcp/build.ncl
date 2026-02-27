let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let xorgproto = import "../xorgproto/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "1.1.5" in
{
  name = "libxdmcp",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libXdmcp-%{version}.tar.xz",
      sha256 = "d8a5222828c3adab70adf69a5583f1d32eb5ece04304f7f8392b6a353aa2228c",
      extract = true,
      strip_prefix = "libXdmcp-%{version}",
    } | Source,
    base,
    make,
    toolchain,
    pkgconf,
    xorgproto,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libXdmcp.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "test -f /usr/lib/libXdmcp.so.6 || test -f /usr/lib/x86_64-linux-gnu/libXdmcp.so.6"],
        ],
      } | Test,
  },
  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
