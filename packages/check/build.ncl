let { BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let autoconf = import "../autoconf/build.ncl" in
let automake = import "../automake/build.ncl" in
let bash = import "../bash/build.ncl" in
let m4 = import "../m4/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let libtool = import "../libtool/build.ncl" in
let perl = import "../perl/build.ncl" in
let make = import "../make/build.ncl" in
{
  name = "check",
  inputs = [
    { file = "build.sh" } | Local,
    {
      # https://github.com/libcheck/check/releases/download/0.15.2/check-0.15.2.tar.gz
      url = "gs://minimal-staging-archives/check-0.15.2.tar.gz",
      sha256 = "a8de4e0bacfb4d76dd1c618ded263523b53b85d92a146d8835eb1a52932fa20a",
    } | Source,
    base,
    toolchain,
    coreutils,
    automake,
    autoconf,
    m4,
    pkgconf,
    libtool,
    perl,
    bash,
    make,
  ],
  runtime_deps = [],

  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },
} | BuildSpec
