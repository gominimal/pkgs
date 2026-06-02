let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputLib, Source, Test, .. } = import "minimal.ncl" in

let base = import "../base/build.ncl" in
let cabal = import "../cabal/build.ncl" in
let ghc = import "../ghc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.14.0.0" in

{
  name = "haskell-language-server",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/haskell/haskell-language-server/archive/refs/tags/%{version}.tar.gz",
      sha256 = "02fdd2ea8048cddce0872f78fcc4ba15558f751333c97d24b9abadac8ee27dcb",
      extract = true,
      strip_prefix = "haskell-language-server-%{version}",
    } | Source,
    base,
    ghc,
    cabal,
  ],

  runtime_deps = [glibc],

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
