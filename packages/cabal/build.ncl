let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ghc = import "../ghc/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let python = import "../python/build.ncl" in

let version = "3.18.1.0" in
{
  name = "cabal",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "update_bootstrap_json.py" } | Local,
    {
      url = "https://github.com/haskell/cabal/archive/refs/tags/cabal-install-v%{version}.tar.gz",
      sha256 = "ae794d9b803b31922a80338f4671a3abd8eba995424db549438ad211f4657193",
      extract = true,
      strip_prefix = "cabal-cabal-install-v%{version}",
    } | Source,
    base,
    ghc,
    python,
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
    cabal = { glob = "usr/bin/cabal" } | OutputBin,
    docs = { glob = "usr/share/doc/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "haskell",
        repo = "cabal",
      },
      build_cost_multiple = 3,
    } | Attrs,
} | BuildSpec
