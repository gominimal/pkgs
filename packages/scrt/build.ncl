let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "0.3.3" in
{
  name = "scrt",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/loderunner/scrt/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "72ac4c594e8c89b43d679118d571f2726a86628b324b33486fba4331b1dc39de",
      extract = true,
      strip_prefix = "scrt-%{version}",
    } | Source,
    base,
    go,
    toolchain,
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    scrt = { glob = "usr/bin/scrt" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "loderunner",
        repo = "scrt",
      },
    } | Attrs,
} | BuildSpec
