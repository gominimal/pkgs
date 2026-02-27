let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let meson = import "../meson/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let expat = import "../expat/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.16.2" in
{
  name = "dbus",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/dbus-%{version}.tar.xz",
      sha256 = "0ba2a1a4b16afe7bceb2c07e9ce99a8c2c3508e5dec290dbb643384bd6beb7e2",
      extract = true,
      strip_prefix = "dbus-%{version}",
    } | Source,
    base,
    meson,
    ninja,
    pkgconf,
    toolchain,
    expat,
  ],
  runtime_deps = [
    expat,
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/dbus-*" } | OutputBin,
    libs = { glob = "usr/lib/libdbus-1.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    arch-includes = { glob = "usr/lib/dbus-1.0/include/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "test -f /usr/lib/libdbus-1.so.3 || test -f /usr/lib/x86_64-linux-gnu/libdbus-1.so.3"],
        ],
      } | Test,
  },
  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
