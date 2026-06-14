let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let ghc-bootstrap = import "../ghc-bootstrap/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.20.1.1" in
{
  name = "happy",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://hackage.haskell.org/package/happy-%{version}/happy-%{version}.tar.gz",
      sha256 = "8b4e7dc5a6c5fd666f8f7163232931ab28746d0d17da8fa1cbd68be9e878881b",
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
  },

  attrs = {
    upstream_version = version,
    license_spdx = "BSD-2-Clause",
  },
} | BuildSpec
