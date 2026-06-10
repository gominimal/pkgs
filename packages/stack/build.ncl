let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let cabal = import "../cabal/build.ncl" in
let base = import "../base/build.ncl" in
let ghc = import "../ghc/build.ncl" in
let gmp = import "../gmp/build.ncl" in

let version = "3.9.3" in
{
  name = "stack",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/commercialhaskell/stack/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "144bc7eaaf384228f6b0f960ced130b503dc4945ffa42f3ca2037abbc8136c05",
      extract = true,
      strip_prefix = "stack-%{version}",
    } | Source,
    base,
    cabal,
    ghc,
    gmp,
  ],
  runtime_deps = [
    gmp,
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
    stack = { glob = "usr/bin/stack" } | OutputBin,

    docs = { glob = "usr/share/doc/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "commercialhaskell",
        repo = "stack",
      },
      build_cost_multiple = 3,
    } | Attrs,
} | BuildSpec
