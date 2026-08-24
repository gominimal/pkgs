let { BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let ghc-bootstrap = import "../ghc-bootstrap/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "2.1.6" in
{
  name = "happy",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://hackage.haskell.org/package/happy-%{version}/happy-%{version}.tar.gz",
      sha256 = "9b473961010cb5673510f4133d914b9d5ad667b16aafe4a5555d9962dbf05b19",
      extract = true,
    } | Source,
    # Since 2.0 the executable is a thin driver over happy-lib, which also ships
    # the code templates the generated parsers are built from.
    {
      url = "https://hackage.haskell.org/package/happy-lib-%{version}/happy-lib-%{version}.tar.gz",
      sha256 = "b0a130901562fd2b338baeb5b508cd8aed914b300f51c30b0ba8935995b2c2cd",
      extract = true,
    } | Source,
    base,
    bash,
    ghc-bootstrap,
    toolchain,
  ],

  runtime_deps = [
    base,
    gmp,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    happy = { glob = "usr/bin/happy" } | OutputBin,
    data = { glob = "usr/share/**" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    source_provenance = {
      category = 'GithubRepo,
      owner = "haskell",
      repo = "happy",
    },
    license_spdx = "BSD-2-Clause",
  },

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "/usr/bin/happy --version | grep -q 'Happy Version %{version}'"],
        ],
      } | Test,
    # Generating a parser is what proves the package is whole: happy reads its
    # code templates out of happy-lib's data directory at runtime, so this fails
    # if those files are missing from the outputs or installed under a path the
    # binary wasn't compiled to look in.
    generates_a_parser =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "set -euo pipefail\ncat > calc.y <<'EOF'\n{\nmodule Calc where\n}\n%name calc\n%tokentype { Token }\n%error { parseError }\n%token int { TInt $$ }\n%%\nExp : int { $1 }\n{\ndata Token = TInt Int\nparseError :: [Token] -> a\nparseError _ = error \"parse error\"\n}\nEOF\n/usr/bin/happy --ghc calc.y -o calc.hs\n# happyParse comes from HappyTemplate.hs, so finding it means the template\n# was located and inlined rather than the parser being generated empty.\ngrep -q happyParse calc.hs"],
        ],
      } | Test,
  },
} | BuildSpec
