let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputLib, Source, Test, .. } = import "minimal.ncl" in

let alex = import "../alex/build.ncl" in
let base = import "../base/build.ncl" in
let cabal = import "../cabal/build.ncl" in
let ghc = import "../ghc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let happy = import "../happy/build.ncl" in
let libffi = import "../libffi/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "2.15.0.0" in

{
  name = "haskell-language-server",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/haskell/haskell-language-server/archive/refs/tags/%{version}.tar.gz",
      sha256 = "ca5e7637ea62cf8d1223fcba63f64b77924e85ccfb5b716075d030e272f1fbbe",
      extract = true,
      strip_prefix = "haskell-language-server-%{version}",
    } | Source,
    base,
    ghc,
    cabal,
    alex,
    happy,
  ],

  runtime_deps = [glibc, gmp, libffi, zlib],

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
    hls = { glob = "usr/bin/haskell-language-server" } | OutputBin,
    libs = { glob = "usr/lib/*.so*" } | OutputLib,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "haskell",
        repo = "haskell-language-server",
      },
      build_cost_multiple = 4,
    } | Attrs,

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [],
        cmds = [["haskell-language-server", "--version"]],
      } | Test,
  },
} | BuildSpec
