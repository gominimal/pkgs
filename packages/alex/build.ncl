let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let ghc-bootstrap = import "../ghc-bootstrap/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "3.5.4.2" in
{
  name = "alex",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://hackage.haskell.org/package/alex-%{version}/alex-%{version}.tar.gz",
      sha256 = "df481dc960e2c59a30395f7335031fd4ef8773b8a42894a4f2320e00ff474418",
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
    alex = { glob = "usr/bin/alex" } | OutputBin,
  },

  attrs = {
    upstream_version = version,
    source_provenance = {
      category = 'GithubRepo,
      owner = "haskell",
      repo = "alex",
    },
    license_spdx = "BSD-3-Clause",
  },
} | BuildSpec
