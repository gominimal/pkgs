let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let xorgproto = import "../xorgproto/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "1.3.3" in
{
  name = "libxshmfence",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libxshmfence-%{version}.tar.xz",
      sha256 = "d4a4df096aba96fea02c029ee3a44e11a47eb7f7213c1a729be83e85ec3fde10",
      extract = true,
      strip_prefix = "libxshmfence-%{version}",
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
    libs = { glob = "usr/lib/libxshmfence.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "test -f /usr/lib/libxshmfence.so.1 || test -f /usr/lib/x86_64-linux-gnu/libxshmfence.so.1"],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
