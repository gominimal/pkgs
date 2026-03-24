let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in

let version = "4.0.5" in
{
  name = "procps-ng",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/procps-ng-%{version}.tar.xz",
      sha256 = "c2e6d193cc78f84cd6ddb72aaf6d5c6a9162f0470e5992092057f5ff518562fa"
    } | Source,
    base,
    pkgconf,
    make,
    toolchain,
  ],
  runtime_deps = [
    ncurses,
  ],
  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    sbins = { glob = "usr/sbin/*" } | OutputBin,

    libs = { glob = "usr/lib/*.so*" } | OutputLib,
    ltconfigs = { glob = "usr/lib/libproc2.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*" } | OutputData,

    includes = { glob = "usr/include/libproc2/*" } | OutputData,
  },
  attrs = {
    upstream_version = version,
  },
} | BuildSpec
