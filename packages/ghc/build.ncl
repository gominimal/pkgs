let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let perl = import "../perl/build.ncl" in
let python = import "../python/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let libffi = import "../libffi/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
let xz = import "../xz/build.ncl" in
let tar = import "../tar/build.ncl" in
let autoconf = import "../autoconf/build.ncl" in
let automake = import "../automake/build.ncl" in
let m4 = import "../m4/build.ncl" in
let curl = import "../curl/build.ncl" in
let make = import "../make/build.ncl" in

let version = "9.10.1" in
{
  name = "ghc",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://downloads.haskell.org/~ghc/%{version}/ghc-%{version}-src.tar.xz",
      sha256 = "bf386a302d4ee054791ffd51748900f15d71760fd199157922d120cc1f89e2f7",
      extract = false,
    } | Source,
    {
      url = "https://downloads.haskell.org/~ghc/9.8.2/ghc-9.8.2-x86_64-deb11-linux.tar.xz",
      sha256 = "ee9d424c614dd4b92b0104e812fb92016bf3d3ffd5e51a8af544634b9d817028",
      extract = false,
    } | Source,
    {
      url = "https://downloads.haskell.org/~ghc/9.8.2/ghc-9.8.2-aarch64-deb11-linux.tar.xz",
      sha256 = "b7f27d53cf20645833bcff2fa6308b221c39eeac1de3fe074598090731848672",
      extract = false,
    } | Source,
    {
      url = "https://hackage.haskell.org/package/alex-3.5.1.0/alex-3.5.1.0.tar.gz",
      sha256 = "c92efe86f8eb959ee03be6c04ee57ebc7e4abc75a6c4b26551215d7443e92a07",
      extract = false,
    } | Source,
    {
      url = "https://hackage.haskell.org/package/happy-1.20.1.1/happy-1.20.1.1.tar.gz",
      sha256 = "8b4e7dc5a6c5fd666f8f7163232931ab28746d0d17da8fa1cbd68be9e878881b",
      extract = false,
    } | Source,
    base,
    bash,
    binutils,
    toolchain,
    perl,
    python,
    gmp,
    xz,
    tar,
    curl,
    make,
    autoconf,
    automake,
    m4,
  ],

  runtime_deps = [
    base,
    binutils,
    gmp,
    libffi,
    linux_headers,
    toolchain,
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",

  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,

    libghc = { glob = "usr/lib/ghc*/**" } | OutputData,
    libs = { glob = "usr/lib/**/*.so*" } | OutputLib,
  },

  attrs =
    {
      upstream_version = version,
      build_cost_multiple = 6,
    } | Attrs,

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [],
        cmds = [["ghc", "--version"]],
      } | Test,
  },
} | BuildSpec
