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

let version = "9.12.2" in
{
  name = "ghc-bootstrap",

  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://downloads.haskell.org/~ghc/%{version}/ghc-%{version}-x86_64-deb11-linux.tar.xz",
          sha256 = "47d5faba492545b49b8dd49a79e64b4ef8eb4b1632d4ddc64355ce4e812eec75",
          extract = false,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://downloads.haskell.org/~ghc/%{version}/ghc-%{version}-aarch64-deb10-linux.tar.xz",
          sha256 = "6048eae62ede069459398fa6f2e92ab9719e1b83e93a9014e6a410c54ed2755f",
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
    binary_from = "https://downloads.haskell.org/~ghc/",
    license_spdx = "BSD-3-Clause",
  },
} | BuildSpec
