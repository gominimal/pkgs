let { BuildSpec, Local, OutputData, OutputLib, Prebuilt, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let meson = import "../meson/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "0.46.4" in
{
  name = "pixman",
  inputs = [
    { file = "build.sh" } | Local,
    {
      # https://www.cairographics.org/releases/pixman-0.46.4.tar.gz
      url = "gs://minimal-staging-archives/pixman-%{version}.tar.gz",
      sha256 = "d09c44ebc3bd5bee7021c79f922fe8fb2fb57f7320f55e97ff9914d2346a591c",
      extract = true,
      strip_prefix = "pixman-%{version}",
    } | Source,
    base,
    toolchain,
    make,
    ninja,
    meson,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libpixman*.so*" } | OutputLib,

    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },
} | BuildSpec
