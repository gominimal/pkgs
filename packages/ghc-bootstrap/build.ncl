let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let make = import "../make/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let perl = import "../perl/build.ncl" in
let tar = import "../tar/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let xz = import "../xz/build.ncl" in

let version = "9.8.1" in
{
  name = "ghc-bootstrap",

  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://downloads.haskell.org/~ghc/%{version}/ghc-%{version}-x86_64-deb11-linux.tar.xz",
          sha256 = "ca4dde3a6f34f1fe6d0783767671f02e862f1b0222ef2dc2c5c68cc2abc1abae",
          extract = false,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://downloads.haskell.org/~ghc/%{version}/ghc-%{version}-aarch64-deb10-linux.tar.xz",
          sha256 = "aab7af72614f8bf9ca624407aa4dbc69bc009c2b4cc1a0f3c062008db81bdb95",
          extract = false,
        } | Source,
    } target,
    base,
    bash,
    gmp,
    make,
    ncurses,
    perl,
    tar,
    toolchain,
    xz,
  ],

  runtime_deps = [
    base,
    gmp,
    ncurses,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/ghc-%{version}/**", allow_executable = true } | OutputData,
    libtinfo = { glob = "usr/lib/*.so*" } | OutputLib,
  },

  attrs = {
    upstream_version = version,
    license_spdx = "BSD-3-Clause",
  },
} | BuildSpec
