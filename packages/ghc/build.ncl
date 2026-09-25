let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let alex = import "../alex/build.ncl" in
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
let ghc-bootstrap = import "../ghc-bootstrap/build.ncl" in # arm64 boot: a prebuilt bindist
let ghc-9-6-7 = import "../ghc-9.6.7/build.ncl" in # amd64 boot: the top of the source-only ladder
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # the amd64 boot's binaries and C wrapper use its sysroot
let happy = import "../happy/build.ncl" in

let version = "9.10.3" in
{
  name = "ghc",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://downloads.haskell.org/~ghc/%{version}/ghc-%{version}-src.tar.xz",
      sha256 = "d266864b9e0b7b741abe8c9d6a790d7c01c21cf43a1419839119255878ebc59a",
      extract = false,
    } | Source,
    alex,
    base,
    bash,
    happy,
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
  ]
  # The boot compiler and the offline sources Hadrian is built from. amd64 boots from the ghc-9.6.7
  # rung (7.6.3 -> ... -> 9.2.8 -> 9.6.7, all built from source); arm64 from the prebuilt 9.8.1
  # bindist. build.sh picks whichever is present.
  @ (
    match {
      { arch = 'Amd64, .. } =>
        [
          ghc-9-6-7,
          glibc-bedrock,
          {
            url = "https://downloads.haskell.org/~ghc/%{version}/hadrian-bootstrap-sources/hadrian-bootstrap-sources-9.6.4.tar.gz",
            sha256 = "1bac1634cf6a396e77df044d57a96757e84f5d0cf4f1c113637dde5bee7104ee",
            extract = false,
          } | Source,
        ],
      { arch = 'Arm64, .. } =>
        [
          ghc-bootstrap,
          {
            url = "https://downloads.haskell.org/~ghc/%{version}/hadrian-bootstrap-sources/hadrian-bootstrap-sources-9.8.1.tar.gz",
            sha256 = "eec7233763bc31801fcbc996edc9c1f5abae707c1661deb8b22f0a7c2780b5e9",
            extract = false,
          } | Source,
        ],
    } target
  ),

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

    libghc = { glob = "usr/lib/ghc*/**", allow_executable = true } | OutputData,
    libs = { glob = "usr/lib/**/*.so*" } | OutputLib,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
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
