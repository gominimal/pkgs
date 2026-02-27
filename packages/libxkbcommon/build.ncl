let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let meson = import "../meson/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let bison = import "../bison/build.ncl" in
let m4 = import "../m4/build.ncl" in

let libxcb = import "../libxcb/build.ncl" in
let libxml2 = import "../libxml2/build.ncl" in
let xorgproto = import "../xorgproto/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.13.1" in
{
  name = "libxkbcommon",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/xkbcommon/libxkbcommon/xkbcommon-%{version}.tar.gz",
      sha256 = "aeb951964c2f7ecc08174cb5517962d157595e9e3f38fc4a130b91dc2f9fec18",
      extract = true,
      strip_prefix = "libxkbcommon-xkbcommon-%{version}",
    } | Source,
    base,
    meson,
    ninja,
    pkgconf,
    toolchain,
    bison,
    m4,
    libxcb,
    libxml2,
    xorgproto,
  ],
  runtime_deps = [
    libxcb,
    libxml2,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libxkbcommon*.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "test -f /usr/lib/libxkbcommon.so.0 || test -f /usr/lib/x86_64-linux-gnu/libxkbcommon.so.0"],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "xkbcommon",
        repo = "libxkbcommon",
      },
    } | Attrs,
} | BuildSpec
