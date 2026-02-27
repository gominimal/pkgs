let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let meson = import "../meson/build.ncl" in

let version = "2025.1" in
{
  name = "xorgproto",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/xorgproto-%{version}.tar.xz",
      sha256 = "56898c716c0578df8a2d828c9c3e5c528277705c0484381a81960fe1a67668e8",
      extract = true,
      strip_prefix = "xorgproto-%{version}",
    } | Source,
    base,
    toolchain,
    meson,
    ninja,
  ],
  runtime_deps = [],

  cmd = "./build.sh",

  outputs = {
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfig = { glob = "usr/share/pkgconfig/*.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "test -f /usr/include/X11/X.h"],
          ["/bin/bash", "-c", "test -f /usr/share/pkgconfig/xproto.pc"],
        ],
      } | Test,
  },
} | BuildSpec
