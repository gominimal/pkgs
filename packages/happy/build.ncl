let { BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
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
} | BuildSpec
