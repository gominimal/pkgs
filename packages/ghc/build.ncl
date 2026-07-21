let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
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
let ghc-bootstrap = import "../ghc-bootstrap/build.ncl" in
let happy = import "../happy/build.ncl" in

let version = "9.14.1" in
{
  name = "ghc",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://downloads.haskell.org/~ghc/%{version}/ghc-%{version}-src.tar.xz",
      sha256 = "2a83779c9af86554a3289f2787a38d6aa83d00d136aa9f920361dd693c101e77",
      extract = false,
    } | Source,
    {
      url = "https://downloads.haskell.org/~ghc/%{version}/hadrian-bootstrap-sources/hadrian-bootstrap-sources-9.12.2.tar.gz",
      sha256 = "eec7233763bc31801fcbc996edc9c1f5abae707c1661deb8b22f0a7c2780b5e9",
      extract = false,
    } | Source,
    alex,
    base,
    bash,
    ghc-bootstrap,
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
