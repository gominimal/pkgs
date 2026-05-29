let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let ghc-bootstrap = import "../ghc-bootstrap/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "3.5.1.0" in
{
  name = "alex",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://hackage.haskell.org/package/alex-%{version}/alex-%{version}.tar.gz",
      sha256 = "c92efe86f8eb959ee03be6c04ee57ebc7e4abc75a6c4b26551215d7443e92a07",
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
  },
} | BuildSpec
