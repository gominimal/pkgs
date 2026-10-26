let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let meson = import "../meson/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "1.0.17" in
{
  name = "fribidi",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/fribidi-%{version}.tar.xz",
      sha256 = "6949dcde27d41cebad1fd741fcafc36d55a1020d2d872d4a6eb3914caabbada2",
      extract = true,
      strip_prefix = "fribidi-%{version}",
    } | Source,
    base,
    meson,
    ninja,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    bins = { glob = "usr/bin/fribidi" } | OutputBin,
    libs = { glob = "usr/lib/libfribidi.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "LGPL-2.1-or-later",
      source_provenance = {
        category = 'GithubRepo,
        owner = "fribidi",
        repo = "fribidi",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/fribidi --version",
  },
} | BuildSpec
