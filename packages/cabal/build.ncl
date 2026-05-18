let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ghc = import "../ghc/build.ncl" in
let gmp = import "../gmp/build.ncl" in

let version = "3.16.1.0" in
{
  name = "cabal",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/haskell/cabal/archive/refs/tags/cabal-install-v%{version}.tar.gz",
      sha256 = "d06558ebc56e75e713698b00e2079809f846f06f31cd58401309886a2b84390b",
      extract = true,
      strip_prefix = "cabal-cabal-install-v%{version}",
    } | Source,
    base,
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
    bins = { glob = "usr/bin/*" } | OutputBin,

    mans = { glob = "usr/share/man/**" } | OutputData,
    docs = { glob = "usr/share/doc/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "haskell",
        repo = "cabal",
      },
      build_cost_multiple = 3,
    } | Attrs,
} | BuildSpec
